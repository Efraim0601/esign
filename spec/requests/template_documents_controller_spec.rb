# frozen_string_literal: true

describe 'TemplateDocumentsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, author: user) }

  before { sign_in user }

  describe 'GET /templates/:template_id/documents' do
    it 'returns signed blob proxy paths' do
      allow(ActiveStorage::Blob).to receive(:proxy_path).and_return('/file/test')

      get "/templates/#{template.id}/documents"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to all(eq('/file/test'))
    end
  end

  describe 'POST /templates/:template_id/documents' do
    it 'returns unprocessable when no files or blobs are provided' do
      post "/templates/#{template.id}/documents"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns schema payload when attachments creation succeeds' do
      allow(Templates::CreateAttachments).to receive(:call).and_return([[], []])

      post "/templates/#{template.id}/documents", params: { files: ['fake'] }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['schema']).to eq([])
    end
  end
end
