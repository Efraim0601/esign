# frozen_string_literal: true

describe 'SubmissionsArchivedController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, author: user) }
  let!(:submission) { create(:submission, :with_submitters, template:, created_by_user: user, archived_at: 1.day.ago) }

  before { sign_in user }

  describe 'GET /submissions/archived' do
    it 'renders archived submissions list' do
      get '/submissions/archived'

      expect(response).to have_http_status(:ok)
    end

    it 'supports completed_at date filtering branch' do
      get '/submissions/archived', params: { completed_at_from: 1.day.ago.to_date.to_s }

      expect(response).to have_http_status(:ok)
    end
  end
end
