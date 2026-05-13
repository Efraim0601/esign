# frozen_string_literal: true

describe 'SubmitFormDrawSignatureController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: user) }
  let(:submitter) { submission.submitters.first }

  describe 'GET /p/:slug' do
    it 'redirects to completed page when submitter is already completed' do
      submitter.update_column(:completed_at, Time.current)

      get "/p/#{submitter.slug}"

      expect(response).to redirect_to("/s/#{submitter.slug}/completed")
    end
  end
end
