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
