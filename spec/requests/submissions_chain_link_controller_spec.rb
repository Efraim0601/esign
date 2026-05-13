# frozen_string_literal: true

describe 'SubmissionsChainLinkController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user, preferences: {}) }

  before { sign_in user }

  describe 'POST /submissions/:submission_id/chain_link' do
    it 'enables chain link setting' do
      post "/submissions/#{submission.id}/chain_link"

      expect(response).to redirect_to("/submissions/#{submission.id}")
      expect(submission.reload.preferences['chain_link_enabled']).to be(true)
    end
  end

  describe 'DELETE /submissions/:submission_id/chain_link' do
    it 'disables chain link setting' do
      submission.update_column(:preferences, { 'chain_link_enabled' => true })

      delete "/submissions/#{submission.id}/chain_link"

      expect(response).to redirect_to("/submissions/#{submission.id}")
      expect(submission.reload.preferences['chain_link_enabled']).to be(false)
    end
  end
end
