# frozen_string_literal: true

describe 'SubmissionEventsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }

  before { sign_in user }

  describe 'GET /submissions/:submission_id/events' do
    it 'returns success' do
      get "/submissions/#{submission.id}/events"

      expect(response).to have_http_status(:ok)
    end
  end
end
