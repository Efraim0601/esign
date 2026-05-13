# frozen_string_literal: true

describe 'SubmitFormDownloadController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  describe 'GET /s/:submit_form_slug/download' do
    it 'redirects to completed download route when submitter is already completed' do
      submitter.update!(completed_at: Time.current)

      get "/s/#{submitter.slug}/download"

      expect(response).to redirect_to("/submitters/#{submitter.slug}/download")
    end

    it 'returns unprocessable when submitter is declined' do
      submitter.update!(declined_at: Time.current)

      get "/s/#{submitter.slug}/download"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns attachment download urls when access is allowed' do
      allow(Submitters::AuthorizedForForm).to receive(:call).and_return(true)
      allow(ActiveStorage::Blob).to receive(:proxy_path).and_return('/file/ok')

      get "/s/#{submitter.slug}/download"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to all(eq('/file/ok'))
    end
  end
end
