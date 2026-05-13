# frozen_string_literal: true

describe 'SubmissionsPreviewController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }

  describe 'GET /e/:slug' do
    it 'raises not found when account is archived' do
      account.update!(archived_at: Time.current)

      expect do
        get "/e/#{submission.slug}"
      end.to raise_error(ActionController::RoutingError)
    end

    it 'redirects to completed page when signature is required' do
      template.update!(preferences: template.preferences.merge('require_email_2fa' => true))
      submission.submitters.each { |s| s.update!(completed_at: Time.current) }

      get "/e/#{submission.slug}"

      expect(response).to redirect_to("/e/#{submission.slug}/completed")
    end
  end

  describe 'GET /e/:slug/completed' do
    it 'renders completed page for active account' do
      get "/e/#{submission.slug}/completed"

      expect(response).to have_http_status(:ok)
    end
  end
end
