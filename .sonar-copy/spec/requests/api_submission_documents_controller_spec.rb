# frozen_string_literal: true

describe 'Api::SubmissionDocumentsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:access_token) { create(:access_token, user:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }

  describe 'GET /api/submissions/:submission_id/documents' do
    it 'renders serialized document urls for preview documents' do
      filename = double('filename', base: 'doc-1')
      blob = double('blob')
      attachment = double('attachment', filename: filename, blob: blob)

      allow_any_instance_of(Api::SubmissionDocumentsController).to receive(:build_completed_documents).and_return([attachment])
      allow(ActiveRecord::Associations::Preloader).to receive(:new).and_return(double(call: true))
      allow(Accounts).to receive(:link_expires_at).and_return(Time.current + 1.hour)
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(blob, expires_at: kind_of(Time)).and_return('https://files.test/doc-1')

      get "/api/submissions/#{submission.id}/documents", headers: { 'X-Auth-Token' => access_token.token }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(submission.id)
      expect(body['documents'].first).to include('name' => 'doc-1', 'url' => 'https://files.test/doc-1')
    end
  end
end
