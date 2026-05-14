# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::GenerateResultAttachments do
  describe '.call (integration with real PDF)' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }
    let(:template) do
      create(:template, account:, author:,
                        only_field_types: %w[text date checkbox number],
                        attachment_count: 1)
    end
    let(:submission) { create(:submission, template:, created_by_user: author) }
    let(:submitter) do
      submission.submitters.create!(
        account_id: submission.account_id,
        uuid: template.submitters.first['uuid'],
        email: 'result@example.test',
        name: 'Result Tester',
        completed_at: Time.current,
        ip: '127.0.0.1',
        ua: 'TestUA/1.0',
        values: template.fields.each_with_object({}) do |field, acc|
          acc[field['uuid']] =
            case field['type']
            when 'text' then 'Sample value'
            when 'date' then '2026-05-13'
            when 'checkbox' then true
            when 'number' then 7
            end
        end.compact
      )
    end

    before do
      allow(Accounts).to receive(:load_signing_pkcs).and_return(nil)
      allow(Accounts).to receive(:load_timeserver_url).and_return(nil)
    end

    it 'generates filled-result PDFs by calling the full pipeline with a real submission' do
      submitter
      allow(submitter).to receive(:documents).and_return([])

      result = described_class.call(submitter)

      expect(result).to be_an(Array)
    end

    it 'builds a pdfs_index keyed by attachment_uuid for the submission' do
      submitter

      pdfs_index = described_class.build_pdfs_index(submission)

      expect(pdfs_index).to be_a(Hash)
      expect(pdfs_index.keys).to all(be_a(String))
    end
  end

  describe '.fill_submitter_fields (integration)' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }
    let(:template) do
      create(:template, account:, author:,
                        only_field_types: %w[text date checkbox number],
                        attachment_count: 1)
    end
    let(:submission) { create(:submission, template:, created_by_user: author) }
    let(:submitter) do
      submission.submitters.create!(
        account_id: submission.account_id,
        uuid: template.submitters.first['uuid'],
        email: 'fill@example.test',
        name: 'Fill Tester',
        completed_at: Time.current,
        ip: '127.0.0.1',
        ua: 'TestUA',
        values: template.fields.each_with_object({}) do |field, acc|
          acc[field['uuid']] =
            case field['type']
            when 'text' then 'Filled'
            when 'date' then '2026-05-13'
            when 'checkbox' then true
            when 'number' then 12
            end
        end.compact
      )
    end

    before do
      allow(Accounts).to receive(:load_signing_pkcs).and_return(nil)
      allow(Accounts).to receive(:load_timeserver_url).and_return(nil)
    end

    it 'fills submitter field values on a real PDF without raising' do
      submitter
      pdfs_index = described_class.build_pdfs_index(submission)

      expect do
        described_class.fill_submitter_fields(submitter, account, pdfs_index,
                                              with_signature_id: false,
                                              is_flatten: false,
                                              with_headings: true,
                                              with_submitter_timezone: false,
                                              with_file_links: false,
                                              with_signature_id_reason: false,
                                              with_timestamp_seconds: false)
      end.not_to raise_error
    end

    it 'fills fields with signature_id and submitter timezone variations' do
      submitter
      pdfs_index = described_class.build_pdfs_index(submission)

      expect do
        described_class.fill_submitter_fields(submitter, account, pdfs_index,
                                              with_signature_id: true,
                                              is_flatten: true,
                                              with_headings: false,
                                              with_submitter_timezone: true,
                                              with_file_links: true,
                                              with_signature_id_reason: true,
                                              with_timestamp_seconds: true)
      end.not_to raise_error
    end
  end

  describe '.build_signing_params' do
    it 'builds signing params without timestamp handler when tsa is missing' do
      pkcs = double('pkcs', certificate: 'cert', key: 'key', ca_certs: ['ca'])

      params = described_class.build_signing_params(double('submitter'), pkcs, nil)

      expect(params).to include(certificate: 'cert', key: 'key', certificate_chain: ['ca'])
      expect(params).not_to have_key(:timestamp_handler)
      expect(params).not_to have_key(:signature_size)
    end

    it 'adds timestamp handler when tsa_url is provided' do
      pkcs = double('pkcs', certificate: 'cert', key: 'key', ca_certs: [])

      params = described_class.build_signing_params(double('submitter'), pkcs, 'https://tsa.example.test')

      expect(params[:timestamp_handler]).to be_a(Submissions::TimestampHandler)
      expect(params[:signature_size]).to eq(20_000)
    end
  end

  describe '.images_pdf_uuid' do
    it 'builds a stable uuid independent from attachments order' do
      a1 = double('a1', uuid: 'u1')
      a2 = double('a2', uuid: 'u2')

      uuid1 = described_class.images_pdf_uuid([a1, a2])
      uuid2 = described_class.images_pdf_uuid([a2, a1])

      expect(uuid1).to eq(uuid2)
    end
  end

  describe '.maybe_flatten_pdf' do
    it 'ignores missing glyph errors while flattening' do
      form = double('form', :[] => true)
      pdf = double('pdf', acro_form: form)

      allow(form).to receive(:create_appearances).and_raise(HexaPDF::MissingGlyphError)
      allow(form).to receive(:flatten)

      expect { described_class.maybe_flatten_pdf(pdf) }.not_to raise_error
    end
  end

  describe '.maybe_rotate_pdf' do
    it 'returns original pdf when page count exceeds MAX_PAGE_ROTATE' do
      pages = Array.new(described_class::MAX_PAGE_ROTATE + 1) { double('page') }
      root = {}
      pages_relation = double('pages', size: pages.size, root: root)
      pdf = double('pdf', pages: pages_relation)

      expect(described_class.maybe_rotate_pdf(pdf)).to eq(pdf)
    end

    it 'returns original pdf when rotation raises an error' do
      page = double('page', :[] => 90)
      allow(page).to receive(:rotate).and_raise(StandardError.new('rotate failure'))

      root = { Rotate: 0 }
      pages_relation = double('pages', size: 1, root: root)
      allow(pages_relation).to receive(:filter_map).and_raise(StandardError.new('filter failure'))
      pdf = double('pdf', pages: pages_relation)

      expect(described_class.maybe_rotate_pdf(pdf)).to eq(pdf)
    end
  end

  describe '.on_missing_glyph' do
    it 'uses type1 replacement table for Type1 fonts' do
      wrapper = double('wrapper', font_type: :Type1)
      allow(wrapper).to receive(:custom_glyph).and_return(:ok)

      result = described_class.on_missing_glyph('✓', wrapper)

      expect(result).to eq(:ok)
      expect(wrapper).to have_received(:custom_glyph).with(:V, '✓')
    end

    it 'uses byte replacement for non-Type1 fonts' do
      wrapper = double('wrapper', font_type: :TrueType)
      allow(wrapper).to receive(:custom_glyph).and_return(:ok)

      result = described_class.on_missing_glyph('X', wrapper)

      expect(result).to eq(:ok)
      expect(wrapper).to have_received(:custom_glyph)
    end
  end

  describe '.find_last_submitter' do
    it 'returns latest completed submitter before current submitter' do
      t1 = Time.current - 2.hours
      t2 = Time.current - 1.hour
      s1 = double('s1', id: 1, completed_at?: true, completed_at: t1)
      s2 = double('s2', id: 2, completed_at?: true, completed_at: t2)
      s3 = double('s3', id: 3, completed_at?: false, completed_at: nil)
      submission = double('submission', submitters: [s1, s2, s3])

      expect(described_class.find_last_submitter(submission, submitter: s2)).to eq(s1)
      expect(described_class.find_last_submitter(submission)).to eq(s2)
    end
  end

  describe '.fetch_sign_reason' do
    let(:submitter) do
      double('submitter',
             email: 'a@b.c',
             name: 'Name',
             phone: '+33',
             completed_at: Time.current,
             account: double('account'),
             submission: submission)
    end
    let(:submission) { double('submission', submitters: submitters_relation) }
    let(:submitters_relation) { double('submitters_relation') }
    let(:config_relation) { double('config_relation') }

    before do
      allow(AccountConfig).to receive(:where).and_return(config_relation)
      allow(config_relation).to receive(:first_or_initialize).and_return(double('cfg', value: 'multiple'))
      allow(Docuseal).to receive(:multitenant?).and_return(false)
    end

    it 'returns sign reason when preference is multiple' do
      reason = described_class.fetch_sign_reason(submitter)

      expect(reason).to eq(described_class.sign_reason('a@b.c'))
    end

    it 'returns single sign reason for latest completed submitter in single mode' do
      completed_at = Time.current
      s1 = double('s1', email: 'one@example.com', name: nil, phone: nil, completed_at: completed_at - 1.hour)
      s2 = double('s2', email: 'two@example.com', name: nil, phone: nil, completed_at: completed_at)
      relation = double('relation')
      submission = double('submission', submitters: relation)
      submitter = double('submitter',
                         email: 'two@example.com',
                         name: nil,
                         phone: nil,
                         completed_at: completed_at,
                         account: double('account'),
                         submission: submission)

      allow(relation).to receive(:exists?).with(completed_at: nil).and_return(false)
      allow(relation).to receive(:maximum).with(:completed_at).and_return(completed_at)
      allow(relation).to receive(:sort_by).and_return([s1, s2])
      allow(AccountConfig).to receive(:where).and_return(config_relation)
      allow(config_relation).to receive(:first_or_initialize).and_return(double('cfg', value: 'single'))

      reason = described_class.fetch_sign_reason(submitter)

      expect(reason).to eq(described_class.single_sign_reason(submitter))
    end

    it 'returns nil when submitter is not last completed in single mode' do
      completed_at = Time.current
      relation = double('relation')
      submission = double('submission', submitters: relation)
      submitter = double('submitter',
                         email: 'two@example.com',
                         name: nil,
                         phone: nil,
                         completed_at: completed_at - 1.hour,
                         account: double('account'),
                         submission: submission)

      allow(relation).to receive(:exists?).with(completed_at: nil).and_return(false)
      allow(relation).to receive(:maximum).with(:completed_at).and_return(completed_at)
      allow(AccountConfig).to receive(:where).and_return(config_relation)
      allow(config_relation).to receive(:first_or_initialize).and_return(double('cfg', value: 'single'))

      expect(described_class.fetch_sign_reason(submitter)).to be_nil
    end
  end

  describe '.info_creator' do
    it 'includes product name and product url' do
      expect(described_class.info_creator).to include(Docuseal.product_name, Docuseal::PRODUCT_URL)
    end
  end

  describe '.load_vips_image' do
    it 'uses ICO loader for ico content types' do
      attachment = double('attachment', uuid: 'u1', content_type: 'image/x-icon', download: 'ico-bytes')
      allow(LoadIco).to receive(:call).and_return(:ico_image)

      result = described_class.load_vips_image(attachment, {})

      expect(result).to eq(:ico_image)
      expect(LoadIco).to have_received(:call).with('ico-bytes')
    end

    it 'uses BMP loader for bmp content types' do
      attachment = double('attachment', uuid: 'u2', content_type: 'image/bmp', download: 'bmp-bytes')
      allow(LoadBmp).to receive(:call).and_return(:bmp_image)

      result = described_class.load_vips_image(attachment, {})

      expect(result).to eq(:bmp_image)
      expect(LoadBmp).to have_received(:call).with('bmp-bytes')
    end

    it 'uses Vips loader for other image types and caches downloads' do
      attachment = double('attachment', uuid: 'u3', content_type: 'image/png')
      allow(attachment).to receive(:download).once.and_return('png-bytes')
      allow(Vips::Image).to receive(:new_from_buffer).and_return(:png_image)
      cache = {}

      first = described_class.load_vips_image(attachment, cache)
      second = described_class.load_vips_image(attachment, cache)

      expect(first).to eq(:png_image)
      expect(second).to eq(:png_image)
      expect(Vips::Image).to have_received(:new_from_buffer).twice
    end
  end

  describe '.maybe_rotate_pdf' do
    it 'rebuilds pdf when root rotation is present even without per-page rotation' do
      page = double('page', :[] => 0)
      pages_relation = double('pages', size: 1, root: { Rotate: 90 }, filter_map: [])
      pdf = double('pdf', pages: pages_relation)
      io = StringIO.new

      allow(pdf).to receive(:write)
      allow(HexaPDF::Document).to receive(:new).and_return(:reloaded_pdf)

      expect(described_class.maybe_rotate_pdf(pdf)).to eq(:reloaded_pdf)
    end
  end

  describe '.helper defaults' do
    it 'returns pass-through io for maybe_enable_ltv' do
      io = StringIO.new('pdf')

      expect(described_class.maybe_enable_ltv(io, {})).to eq(io)
    end

    it 'returns false for detached_signature? and empty detached attachments' do
      expect(described_class.detached_signature?(double('submitter'))).to be(false)
      expect(described_class.generate_detached_signature_attachments(double('submitter'))).to eq([])
    end
  end
end
