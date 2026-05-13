# frozen_string_literal: true

describe 'ChainSubmitController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  before do
    submission.update!(preferences: submission.preferences.merge('chain_link_enabled' => true))
    allow(RateLimit).to receive(:call)
  end

  describe 'GET /c/:slug' do
    it 'renders chain submit page' do
      get "/c/#{submission.slug}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /c/:slug' do
    it 'redirects with error when email does not match a submitter' do
      post "/c/#{submission.slug}", params: { email: 'unknown@example.test' }

      expect(response).to redirect_to("/c/#{submission.slug}")
    end

    it 'redirects to submitter form when email resolves' do
      post "/c/#{submission.slug}", params: { email: submitter.email }

      expect(response).to redirect_to("/s/#{submitter.slug}")
    end
  end
end
