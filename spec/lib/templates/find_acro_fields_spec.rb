# frozen_string_literal: true

RSpec.describe Templates::FindAcroFields do
  FieldStub = Struct.new(:attrs, :full_field_name, :field_type, :concrete_field_type, :field_value,
                         :allowed_values, :field_name_hint, keyword_init: true) do
    def [](key)
      attrs[key]
    end

    def try(sym)
      return field_name_hint if sym == :field_name

      nil
    end
  end

  describe '.correct_coordinates' do
    it 'applies crop shift and media box origin offset' do
      x, y = described_class.correct_coordinates(10, 20, [3, -2], [1, 5])

      expect(x).to eq(12)
      expect(y).to eq(13)
    end
  end

  describe '.build_options' do
    it 'builds options for select and skips placeholder labels' do
      options = described_class.build_options(['Select one', 'Alpha', 'Beta'], 'select')

      expect(options.map { |o| o[:value] }).to eq(%w[Alpha Beta])
      expect(options).to all(include(:uuid, :value))
    end

    it 'normalizes numeric and single-value radio options to blank values' do
      options = described_class.build_options([:one, :one], 'radio')

      expect(options.map { |o| o[:value] }).to eq(['', ''])
    end

    it 'supports pair options by taking display value' do
      options = described_class.build_options([['1', 'First'], ['2', 'Second']], 'multiple')

      expect(options.map { |o| o[:value] }).to eq(%w[First Second])
    end
  end

  describe '.build_field_properties' do
    it 'builds text field props and maps alignment from Q flag' do
      field = FieldStub.new(
        attrs: { Q: 2, TU: 'Readable name' },
        full_field_name: 'Field Name',
        field_type: :Tx,
        concrete_field_type: :text_field,
        field_value: 'hello',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('text')
      expect(result[:default_value]).to eq('hello')
      expect(result.dig(:preferences, :align)).to eq('right')
      expect(result[:description]).to eq('Readable name')
    end

    it 'builds radio field from button options' do
      field = FieldStub.new(
        attrs: { Opt: %w[One Two] },
        full_field_name: 'Radio',
        field_type: :Btn,
        concrete_field_type: :radio_button,
        field_value: 'Two',
        allowed_values: %w[One Two]
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('radio')
      expect(result[:default_value]).to eq('Two')
      expect(result[:options].size).to eq(2)
    end

    it 'returns empty hash for invalid BBox radio groups' do
      field = FieldStub.new(
        attrs: { Kids: [1, 2] },
        full_field_name: 'Radio group',
        field_type: :Btn,
        concrete_field_type: :radio_button,
        field_value: :A,
        allowed_values: [:BBox, :A]
      )

      expect(described_class.build_field_properties(field)).to eq({})
    end

    it 'maps select placeholders to nil default value' do
      field = FieldStub.new(
        attrs: { Opt: ['Select one', 'France'] },
        full_field_name: 'Country',
        field_type: :Ch,
        concrete_field_type: :combo_box,
        field_value: 'Select one',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('select')
      expect(result[:default_value]).to be_nil
    end

    it 'detects date text fields from AFDate javascript' do
      field = FieldStub.new(
        attrs: {
          AA: {
            F: { JS: 'AFDate_FormatEx("dd/mm/yyyy");' }
          }
        },
        full_field_name: 'Date',
        field_type: :Tx,
        concrete_field_type: :text_field,
        field_value: '11/05/2026',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('date')
      expect(result.dig(:preferences, :format)).to eq('DD/MM/YYYY')
    end

    it 'maps signature names containing initials to initials type' do
      field = FieldStub.new(
        attrs: {},
        full_field_name: 'Initials',
        field_type: :Sig,
        concrete_field_type: nil,
        field_value: nil,
        allowed_values: [],
        field_name_hint: 'User Initials'
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('initials')
    end
  end

  describe '.build_field_properties additional branches' do
    it 'builds checkbox field for button without options or kids' do
      field = FieldStub.new(
        attrs: {},
        full_field_name: 'Confirm',
        field_type: :Btn,
        concrete_field_type: :check_box,
        field_value: 'Yes',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('checkbox')
      expect(result[:default_value]).to be(true)
    end

    it 'builds radio field from kids when allowed values are multiple' do
      field = FieldStub.new(
        attrs: { Kids: [1, 2] },
        full_field_name: 'Color',
        field_type: :Btn,
        concrete_field_type: :radio_button,
        field_value: 'red',
        allowed_values: %w[red green blue]
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('radio')
      expect(result[:default_value]).to eq('red')
      expect(result[:options].size).to eq(3)
    end

    it 'builds multi_select field type' do
      field = FieldStub.new(
        attrs: { Opt: %w[A B C] },
        full_field_name: 'Choices',
        field_type: :Ch,
        concrete_field_type: :multi_select,
        field_value: ['A', 'B'],
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('multiple')
      expect(result[:default_value]).to eq(['A', 'B'])
    end

    it 'builds cells field for comb text field' do
      field = FieldStub.new(
        attrs: {},
        full_field_name: 'Identifier',
        field_type: :Tx,
        concrete_field_type: :comb_text_field,
        field_value: '12345',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('cells')
    end

    it 'builds signature field when name does not include initials hint' do
      field = FieldStub.new(
        attrs: {},
        full_field_name: 'Signature',
        field_type: :Sig,
        concrete_field_type: nil,
        field_value: nil,
        allowed_values: [],
        field_name_hint: 'Manager Signature'
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('signature')
    end

    it 'falls back to empty hash for unrecognised field type' do
      field = FieldStub.new(
        attrs: {},
        full_field_name: 'Something',
        field_type: :Other,
        concrete_field_type: nil,
        field_value: nil,
        allowed_values: []
      )

      expect(described_class.build_field_properties(field)).to eq({})
    end

    it 'detects date fields from K action JS even without F action' do
      field = FieldStub.new(
        attrs: {
          AA: { K: { JS: 'AFDate_FormatEx("yyyy-mm-dd")' }, F: { JS: '' } }
        },
        full_field_name: 'Date',
        field_type: :Tx,
        concrete_field_type: :text_field,
        field_value: '2026-05-13',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result[:type]).to eq('date')
    end

    it 'skips description when TU equals the full field name' do
      field = FieldStub.new(
        attrs: { TU: 'Same Name' },
        full_field_name: 'Same Name',
        field_type: :Tx,
        concrete_field_type: :text_field,
        field_value: '',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result).not_to have_key(:description)
    end

    it 'skips description when TU is in SKIP_FIELD_DESCRIPTION' do
      field = FieldStub.new(
        attrs: { TU: 'undefined' },
        full_field_name: 'Field',
        field_type: :Tx,
        concrete_field_type: :text_field,
        field_value: '',
        allowed_values: []
      )

      result = described_class.build_field_properties(field)

      expect(result).not_to have_key(:description)
    end
  end

  describe '.build_options additional branches' do
    it 'skips placeholder labels in multiple types' do
      options = described_class.build_options(['Select an option', 'Apple', 'Banana'], 'multiple')

      expect(options.map { |o| o[:value] }).to include('Apple', 'Banana')
    end

    it 'handles symbol options that look like numbers' do
      options = described_class.build_options([:'42'])

      expect(options.first[:value]).to eq('')
    end
  end

  describe '.compute_area_geometry' do
    it 'computes normalized area attributes from PDF rect' do
      page = double('page', index: 2)
      allow(page).to receive(:[]).with(:CropBox).and_return(nil)
      allow(page).to receive(:[]).with(:MediaBox).and_return([0, 0, 100, 200])
      child_field = double('field')
      allow(child_field).to receive(:[]).with(:Rect).and_return([10, 20, 30, 60])
      allow(child_field).to receive(:[]).with(:MaxLen).and_return(nil)
      allow(child_field).to receive(:try).with(:concrete_field_type).and_return(nil)
      attachment = double('attachment', uuid: 'att-1')

      attrs = described_class.compute_area_geometry(child_field, page, attachment)

      expect(attrs[:page]).to eq(2)
      expect(attrs[:x]).to be_within(0.001).of(0.1)
      expect(attrs[:w]).to be_within(0.001).of(0.2)
      expect(attrs[:attachment_uuid]).to eq('att-1')
      expect(attrs).not_to have_key(:cell_w)
    end

    it 'adds cell_w when comb_text_field with MaxLen' do
      page = double('page', index: 0)
      allow(page).to receive(:[]).with(:CropBox).and_return(nil)
      allow(page).to receive(:[]).with(:MediaBox).and_return([0, 0, 100, 100])
      child_field = double('field')
      allow(child_field).to receive(:[]).with(:Rect).and_return([0, 0, 40, 10])
      allow(child_field).to receive(:[]).with(:MaxLen).and_return(4)
      allow(child_field).to receive(:try).with(:concrete_field_type).and_return(:comb_text_field)
      attachment = double('attachment', uuid: 'att-2')

      attrs = described_class.compute_area_geometry(child_field, page, attachment)

      expect(attrs[:cell_w]).to be_within(0.001).of(0.1)
    end
  end

  describe '.build_area' do
    it 'returns nil when page is not found in annots_index' do
      child_field = double('field', hash: 123)
      expect(described_class.build_area(child_field, {}, double('att'))).to be_nil
    end

    it 'returns nil when Rect is missing' do
      child_field = double('field', hash: 123)
      allow(child_field).to receive(:[]).with(:Rect).and_return(nil)
      page = double('page')
      expect(described_class.build_area(child_field, { 123 => page }, double('att'))).to be_nil
    end

    it 'returns nil when computed width/height is zero' do
      child_field = double('field', hash: 456)
      allow(child_field).to receive(:[]).with(:Rect).and_return([10, 10, 10, 10])
      allow(child_field).to receive(:[]).with(:MaxLen).and_return(nil)
      allow(child_field).to receive(:try).with(:concrete_field_type).and_return(nil)
      page = double('page', index: 0)
      allow(page).to receive(:[]).with(:CropBox).and_return(nil)
      allow(page).to receive(:[]).with(:MediaBox).and_return([0, 0, 100, 100])

      expect(described_class.build_area(child_field, { 456 => page }, double('att', uuid: 'a'))).to be_nil
    end
  end

  describe '.maybe_assign_option_uuids' do
    it 'assigns matching option uuid to each area for radio/multiple field' do
      areas = [{}, {}]
      props = { type: 'radio', options: [{ uuid: 'o1' }, { uuid: 'o2' }] }

      described_class.maybe_assign_option_uuids(props, areas)

      expect(areas[0][:option_uuid]).to eq('o1')
      expect(areas[1][:option_uuid]).to eq('o2')
    end

    it 'rebuilds options when area count does not match' do
      areas = [{}, {}, {}]
      props = { type: 'multiple', options: [{ uuid: 'o1' }] }

      described_class.maybe_assign_option_uuids(props, areas)

      expect(props[:options].size).to eq(3)
      expect(areas.last[:option_uuid]).not_to be_nil
    end

    it 'is a no-op for non-radio/multiple types' do
      areas = [{ original: true }]
      described_class.maybe_assign_option_uuids({ type: 'text' }, areas)
      expect(areas).to eq([{ original: true }])
    end
  end

  describe '.build_field_payload' do
    it 'returns nil when no areas have a matching page in annots_index' do
      field = double('field')
      allow(field).to receive(:[]).with(:Kids).and_return(nil)
      allow(field).to receive(:hash).and_return(0)

      expect(described_class.build_field_payload(field, {}, double('att'))).to be_nil
    end
  end

  describe '.process_fields_array' do
    it 'collects terminal fields and traverses children recursively' do
      child_terminal = double('child_terminal', type: :XXAcroFormField, terminal_field?: true)
      parent = double('parent', type: :XXAcroFormField, terminal_field?: false, :[] => [child_terminal])

      result = described_class.process_fields_array(double('pdf'), [parent])

      expect(result).to eq([child_terminal])
    end

    it 'wraps non-acro objects via HexaPDF wrapper' do
      raw = double('raw', type: :Other)
      wrapped = double('wrapped_terminal', type: :XXAcroFormField, terminal_field?: true)
      allow(HexaPDF::Type::AcroForm::Field).to receive(:wrap).and_return(wrapped)

      result = described_class.process_fields_array(double('pdf'), [raw])

      expect(result).to eq([wrapped])
      expect(HexaPDF::Type::AcroForm::Field).to have_received(:wrap)
    end
  end
end
