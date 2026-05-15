# frozen_string_literal: true

describe 'TemplatesArchivedSubmissionsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, author: user) }
  let!(:submission) { create(:submission, :with_submitters, template:, created_by_user: user, archived_at: 1.day.ago) }

  before { sign_in user }

  describe 'GET /templates/:template_id/archived' do
    it 'renders archived submissions for the template' do
      get "/templates/#{template.id}/archived"

      expect(response).to have_http_status(:ok)
    end

    it 'supports date filtering branch' do
      get "/templates/#{template.id}/archived", params: { completed_at_to: Time.current.to_date.to_s }

      expect(response).to have_http_status(:ok)
    end
  end
end
