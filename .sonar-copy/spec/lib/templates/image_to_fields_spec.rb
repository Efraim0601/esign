# frozen_string_literal: true

RSpec.describe Templates::ImageToFields do
  describe '.build_split_image_regions' do
    it 'splits an image into top and bottom regions' do
      image = double('image', width: 100, height: 80)
      top = double('top')
      bottom = double('bottom')
      allow(image).to receive(:crop).with(0, 0, 100, 40).and_return(top)
      allow(image).to receive(:crop).with(0, 40, 100, 40).and_return(bottom)

      regions = described_class.build_split_image_regions(image)

      expect(regions.size).to eq(2)
      expect(regions[0][:img]).to eq(top)
      expect(regions[0][:offset_y]).to eq(0)
      expect(regions[1][:img]).to eq(bottom)
      expect(regions[1][:offset_y]).to eq(40)
    end
  end

  describe '.build_fields_from_detections' do
    it 'builds normalized field objects and clips overflowing coordinates' do
      detections = {
        xyxy: Numo::SFloat[[10, 20, 130, 90]],
        confidence: Numo::SFloat[0.9],
        class_id: Numo::Int32[0]
      }
      image = double('image', width: 100, height: 100)

      fields = described_class.build_fields_from_detections(detections, image)

      expect(fields.size).to eq(1)
      expect(fields.first.type).to eq('text')
      expect(fields.first.x).to be_within(0.001).of(0.1)
      expect(fields.first.y).to be_within(0.001).of(0.2)
      expect(fields.first.w).to be_within(0.001).of(0.9)
      expect(fields.first.h).to be_within(0.001).of(0.7)
    end
  end

  describe '.trim_image_with_padding' do
    it 'returns original image when padding is nil' do
      image = double('image')

      trimmed, x, y = described_class.trim_image_with_padding(image, nil)

      expect(trimmed).to eq(image)
      expect(x).to eq(0)
      expect(y).to eq(0)
    end

    it 'trims with padding and crops inside bounds' do
      image = double('image', width: 200, height: 100)
      cropped = double('cropped')
      allow(image).to receive(:find_trim).and_return([20, 10, 100, 60])
      allow(image).to receive(:crop).with(15, 5, 172.0, 70).and_return(cropped)

      trimmed, x, y = described_class.trim_image_with_padding(image, 5)

      expect(trimmed).to eq(cropped)
      expect(x).to eq(15)
      expect(y).to eq(5)
    end
  end

  describe '.apply_nms_nmm' do
    it 'returns detections unchanged when empty' do
      detections = { xyxy: Numo::SFloat[], confidence: Numo::SFloat[], class_id: Numo::Int32[] }

      result = described_class.apply_nms_nmm(detections)

      expect(result).to eq(detections)
    end
  end

  describe '.nms' do
    it 'keeps the strongest overlapping detection' do
      detections = {
        xyxy: Numo::SFloat[
          [0.0, 0.0, 10.0, 10.0],
          [1.0, 1.0, 9.0, 9.0],
          [20.0, 20.0, 30.0, 30.0]
        ],
        confidence: Numo::SFloat[0.95, 0.5, 0.7],
        class_id: Numo::Int32[0, 0, 1]
      }

      result = described_class.nms(detections, 0.3)

      expect(result[:xyxy].shape[0]).to eq(2)
      confidences = result[:confidence].to_a
      expect(confidences.any? { |v| (v - 0.95).abs < 0.01 }).to be(true)
      expect(confidences.any? { |v| (v - 0.7).abs < 0.01 }).to be(true)
    end
  end

  describe '.nmm' do
    it 'merges highly overlapping boxes of same class' do
      detections = {
        xyxy: Numo::SFloat[
          [0.0, 0.0, 10.0, 10.0],
          [0.5, 0.5, 9.5, 9.5]
        ],
        confidence: Numo::SFloat[0.9, 0.8],
        class_id: Numo::Int32[0, 0]
      }

      result = described_class.nmm(detections, 0.6, confidence: 0.1)

      expect(result[:xyxy].shape[0]).to eq(1)
      expect(result[:confidence][0]).to be_within(0.01).of(0.9)
    end
  end

  describe '.postprocess_outputs' do
    it 'returns empty detections when all scores are under threshold' do
      boxes = Numo::SFloat[[0.5, 0.5, 0.2, 0.2]]
      logits = Numo::SFloat[[-10.0, -10.0]]
      transform = { scale_x: 1.0, scale_y: 1.0, pad_x: 0, pad_y: 0, trim_offset_x: 0, trim_offset_y: 0 }

      result = described_class.postprocess_outputs(boxes, logits, transform, confidence: 0.99, resolution: 100)

      expect(result[:xyxy].size).to eq(0)
      expect(result[:confidence].size).to eq(0)
      expect(result[:class_id].size).to eq(0)
    end

    it 'maps kept detections back to image coordinates' do
      boxes = Numo::SFloat[[0.5, 0.5, 0.2, 0.2]]
      logits = Numo::SFloat[[10.0, -10.0]]
      transform = { scale_x: 2.0, scale_y: 2.0, pad_x: 10, pad_y: 5, trim_offset_x: 3, trim_offset_y: 7 }

      result = described_class.postprocess_outputs(boxes, logits, transform, confidence: 0.1, resolution: 100)

      expect(result[:xyxy].shape).to eq([1, 4])
      expect(result[:confidence][0]).to be > 0.9
      expect(result[:class_id][0]).to eq(0)
    end
  end
end
