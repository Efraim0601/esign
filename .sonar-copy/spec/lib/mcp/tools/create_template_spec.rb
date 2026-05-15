# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mcp::Tools::CreateTemplate do
  describe '.call' do
    it 'returns error when neither url nor file argument is provided' do
      account = create(:account)
      current_user = create(:user, account:)
      current_ability = Ability.new(current_user)

      result = described_class.call({}, current_user, current_ability)

      expect(result[:isError]).to be(true)
      expect(result[:content].first[:text]).to eq('Provide either url or file')
    end

    it 'creates template from base64 file and normalizes fields when blank' do
      account = double('account', default_template_folder: double('folder'))
      current_user = double('user', account_id: 1, account: account)
      current_ability = double('ability')
      auth_template = double('auth_template')
      template = double('template', id: 9, name: 'Contract', fields: [])
      doc = double('document', uuid: 'doc-1', filename: double('filename', base: 'contract'))
      helpers = double('helpers')

      allow(current_ability).to receive(:authorize!)
      allow(Template).to receive(:new).and_return(auth_template, template)
      allow(template).to receive(:save!)
      allow(template).to receive(:fields=)
      allow(template).to receive(:update!)
      allow(Templates::CreateAttachments).to receive(:call).and_return([[doc], nil])
      allow(Templates::ProcessDocument).to receive(:normalize_attachment_fields).and_return([{ 'uuid' => 'f-1' }])
      allow(WebhookUrls).to receive(:enqueue_events)
      allow(SearchEntries).to receive(:enqueue_reindex)
      allow(Rails.application).to receive(:routes).and_return(double('routes', url_helpers: helpers))
      allow(helpers).to receive(:edit_template_url).and_return('https://app.test/templates/9/edit')

      result = described_class.call(
        { 'file' => Base64.strict_encode64('pdf-bytes'), 'filename' => 'contract.pdf', 'name' => 'Contract' },
        current_user,
        current_ability
      )

      expect(current_ability).to have_received(:authorize!).with(:create, auth_template)
      expect(Templates::CreateAttachments).to have_received(:call).with(template, hash_including(:files), extract_fields: true)
      expect(Templates::ProcessDocument).to have_received(:normalize_attachment_fields).with(template, [doc])
      expect(template).to have_received(:fields=).with([{ 'uuid' => 'f-1' }])
      expect(template).to have_received(:update!).with(schema: [{ attachment_uuid: 'doc-1', name: 'contract' }])
      expect(WebhookUrls).to have_received(:enqueue_events).with(template, 'template.created')
      expect(SearchEntries).to have_received(:enqueue_reindex).with(template)
      expect(JSON.parse(result[:content].first[:text])).to include('id' => 9, 'name' => 'Contract')
    end

    it 'creates template from url and keeps existing fields' do
      account = double('account', default_template_folder: double('folder'))
      current_user = double('user', account_id: 1, account: account)
      current_ability = double('ability')
      auth_template = double('auth_template')
      template = double('template', id: 3, name: 'invoice', fields: [{ 'uuid' => 'existing' }])
      doc = double('document', uuid: 'doc-u', filename: double('filename', base: 'invoice'))
      response = double('response', body: 'pdf-bytes')
      helpers = double('helpers')

      allow(current_ability).to receive(:authorize!)
      allow(Template).to receive(:new).and_return(auth_template, template)
      allow(template).to receive(:save!)
      allow(template).to receive(:update!)
      allow(DownloadUtils).to receive(:call).and_return(response)
      allow(Templates::CreateAttachments).to receive(:call).and_return([[doc], nil])
      allow(Templates::ProcessDocument).to receive(:normalize_attachment_fields)
      allow(WebhookUrls).to receive(:enqueue_events)
      allow(SearchEntries).to receive(:enqueue_reindex)
      allow(Rails.application).to receive(:routes).and_return(double('routes', url_helpers: helpers))
      allow(helpers).to receive(:edit_template_url).and_return('https://app.test/templates/3/edit')

      described_class.call(
        { 'url' => 'https://example.test/files/invoice.pdf' },
        current_user,
        current_ability
      )

      expect(DownloadUtils).to have_received(:call).with('https://example.test/files/invoice.pdf', validate: true)
      expect(Templates::ProcessDocument).not_to have_received(:normalize_attachment_fields)
      expect(template).to have_received(:update!).with(schema: [{ attachment_uuid: 'doc-u', name: 'invoice' }])
    end
  end
end
