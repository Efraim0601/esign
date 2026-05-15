# frozen_string_literal: true

describe 'SubmissionsDownloadController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  describe 'GET /submitters/:slug/download' do
    it 'returns not found when no completed submitter exists' do
      allow(Submissions::EnsureResultGenerated).to receive(:call)

      get "/submitters/#{submitter.slug}/download"

      expect(response).to have_http_status(:not_found)
    end
  end
end
