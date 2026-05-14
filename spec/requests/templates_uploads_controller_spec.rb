# frozen_string_literal: true

describe 'TemplatesUploadsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: :admin) }

  before { sign_in user }

  describe 'GET /new' do
    it 'returns success' do
      get '/new'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /templates_upload' do
    it 'raises when upload params are invalid in local test env' do
      expect do
        post '/templates_upload'
      end.to raise_error(NoMethodError)
    end

    it 'creates a template from a real PDF file' do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/sample-document.pdf'),
        'application/pdf'
      )
      allow(SearchEntries).to receive(:enqueue_reindex)
      allow(WebhookUrls).to receive(:enqueue_events)

      expect do
        post '/templates_upload', params: { files: [file] }
      end.to change(Template, :count).by(1)

      expect(response).to be_redirect
    end

    it 'redirects to root on unexpected error (non-local env)' do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/sample-document.pdf'),
        'application/pdf'
      )
      allow(Templates::CreateAttachments).to receive(:call).and_raise(StandardError.new('upload boom'))
      allow(Rails.env).to receive(:local?).and_return(false)
      allow(Rails.logger).to receive(:error)

      post '/templates_upload', params: { files: [file] }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).not_to be_blank
    end

    it 'renders password prompt when PDF is encrypted' do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/sample-document.pdf'),
        'application/pdf'
      )
      allow(Templates::CreateAttachments).to receive(:call)
        .and_raise(Templates::CreateAttachments::PdfEncrypted)

      post '/templates_upload', params: { files: [file], form_id: 'upload_form' }

      expect(response).to have_http_status(:ok)
    end
  end
end
