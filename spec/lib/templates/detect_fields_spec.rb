# frozen_string_literal: true

RSpec.describe Templates::DetectFields do
  Node = Struct.new(:content, :x, :y, :w, :h, keyword_init: true) do
    def endx
      x + w
    end

    def endy
      y + h
    end
  end

  describe '.sort_fields' do
    it 'sorts by row then by x coordinate' do
      a = Templates::ImageToFields::Field.new(type: 'text', x: 0.4, y: 0.2, w: 0.1, h: 0.1, confidence: 0.5)
      b = Templates::ImageToFields::Field.new(type: 'text', x: 0.1, y: 0.2, w: 0.1, h: 0.1, confidence: 0.5)
      c = Templates::ImageToFields::Field.new(type: 'text', x: 0.2, y: 0.5, w: 0.1, h: 0.1, confidence: 0.5)

      sorted = described_class.sort_fields([a, c, b], y_threshold: 0.05)

      expect(sorted).to eq([b, a, c])
    end
  end

  describe '.type_from_page_node' do
    it 'infers date/number/signature from previous text' do
      field = Templates::ImageToFields::Field.new(type: 'text', x: 0, y: 0, w: 0.1, h: 0.1, confidence: 0.2)

      date_node = described_class::PageNode.new(prev: described_class::PageNode.new(elem: 'Signing Date:'), elem: field)
      number_node = described_class::PageNode.new(prev: described_class::PageNode.new(elem: 'Total price:'), elem: field)
      sign_node = described_class::PageNode.new(prev: described_class::PageNode.new(elem: 'Sign here:'), elem: field)

      expect(described_class.type_from_page_node(date_node)).to eq('date')
      expect(described_class.type_from_page_node(number_node)).to eq('number')
      expect(described_class.type_from_page_node(sign_node)).to eq('signature')
    end
  end

  describe 'overlap helpers' do
    it 'computes iou and overlap correctly' do
      box1 = described_class::TextFieldBox.new(x: 0.1, y: 0.1, w: 0.2, h: 0.2)
      box2 = described_class::TextFieldBox.new(x: 0.2, y: 0.2, w: 0.2, h: 0.2)
      box3 = described_class::TextFieldBox.new(x: 0.6, y: 0.6, w: 0.1, h: 0.1)

      expect(described_class.calculate_iou(box1, box2)).to be > 0
      expect(described_class.calculate_iou(box1, box3)).to eq(0.0)
      expect(described_class.boxes_overlap?(box1, box2)).to be(true)
      expect(described_class.boxes_overlap?(box1, box3)).to be(false)
    end
  end

  describe '.increase_confidence_for_overlapping_fields' do
    it 'increases confidence when text field overlaps enough' do
      image_field = Templates::ImageToFields::Field.new(type: 'text', x: 0.1, y: 0.1, w: 0.4, h: 0.2, confidence: 0.2)
      text_field = described_class::TextFieldBox.new(x: 0.12, y: 0.12, w: 0.35, h: 0.15)

      described_class.increase_confidence_for_overlapping_fields([image_field], [text_field], confidence: 0.9, by: 0.5)

      expect(image_field.confidence).to be_within(0.001).of(0.7)
    end

    it 'returns original fields when text fields are blank' do
      image_field = Templates::ImageToFields::Field.new(type: 'text', x: 0.1, y: 0.1, w: 0.4, h: 0.2, confidence: 0.2)

      result = described_class.increase_confidence_for_overlapping_fields([image_field], [], confidence: 0.9, by: 0.5)

      expect(result.first.confidence).to eq(0.2)
    end
  end

  describe '.extract_text_fields_from_page' do
    it 'groups adjacent underscores into text boxes' do
      nodes = [
        Node.new(content: 'A', x: 0.1, y: 0.1, w: 0.01, h: 0.02),
        Node.new(content: '_', x: 0.2, y: 0.2, w: 0.01, h: 0.02),
        Node.new(content: '_', x: 0.211, y: 0.2, w: 0.01, h: 0.02),
        Node.new(content: 'B', x: 0.4, y: 0.3, w: 0.01, h: 0.02)
      ]
      page = double('page', text_nodes: nodes)

      boxes = described_class.extract_text_fields_from_page(page)

      expect(boxes.size).to eq(1)
      expect(boxes.first.x).to be_within(0.001).of(0.2)
      expect(boxes.first.w).to be > 0.015
    end
  end

  describe '.process_image_attachment' do
    it 'returns empty when page_number does not match image page' do
      io = StringIO.new('image-bytes')
      attachment = double('attachment', image?: true, uuid: 'att-1')

      fields, head = described_class.process_image_attachment(
        io,
        attachment: attachment,
        confidence: 0.2,
        nms: 0.1,
        nmm: 0.5,
        temperature: 1,
        inference: double('inference'),
        page_number: 1
      )

      expect(fields).to eq([])
      expect(head).to be_nil
    end

    it 'maps inference fields to template field payload' do
      io = StringIO.new('image-bytes')
      attachment = double('attachment', image?: true, uuid: 'att-2')
      image = double('image', height: 100)
      detected = Templates::ImageToFields::Field.new(
        type: 'signature', x: 0.1, y: 0.2, w: 0.3, h: 0.1, confidence: 0.8
      )
      inference = double('inference')

      allow(Vips::Image).to receive(:new_from_buffer).and_return(image)
      allow(inference).to receive(:call).and_return([detected])

      fields, head = described_class.process_image_attachment(
        io,
        attachment: attachment,
        inference: inference,
        confidence: 0.2,
        nms: 0.1,
        nmm: 0.5,
        temperature: 1
      )

      expect(head).to be_nil
      expect(fields.size).to eq(1)
      expect(fields.first[:type]).to eq('signature')
      expect(fields.first[:required]).to be(true)
      expect(fields.first[:areas].first[:attachment_uuid]).to eq('att-2')
    end
  end

  describe '.call' do
    it 'dispatches to image processing when attachment is an image' do
      io = StringIO.new('img')
      attachment = double('attachment', image?: true)
      allow(described_class).to receive(:process_image_attachment).and_return([[:field], nil])

      fields, head = described_class.call(io, attachment: attachment)

      expect(fields).to eq([:field])
      expect(head).to be_nil
      expect(described_class).to have_received(:process_image_attachment)
    end

    it 'dispatches to pdf processing when attachment is not an image' do
      io = StringIO.new('pdf')
      attachment = double('attachment', image?: false)
      allow(described_class).to receive(:process_pdf_attachment).and_return([[:field], :head])

      fields, head = described_class.call(io, attachment: attachment)

      expect(fields).to eq([:field])
      expect(head).to eq(:head)
      expect(described_class).to have_received(:process_pdf_attachment)
    end
  end
end
