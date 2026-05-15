# frozen_string_literal: true

describe 'SubmissionsUnarchiveController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user, archived_at: 1.hour.ago) }

  before { sign_in user }

  describe 'POST /submissions/:submission_id/unarchive' do
    it 'unarchives submission and redirects to submission page' do
      post "/submissions/#{submission.id}/unarchive"

      expect(response).to redirect_to("/submissions/#{submission.id}")
      expect(submission.reload.archived_at).to be_nil
    end
  end
end
