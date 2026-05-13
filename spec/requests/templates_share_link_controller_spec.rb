# frozen_string_literal: true

describe 'TemplatesShareLinkController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user, shared_link: false) }

  before { sign_in user }

  describe 'GET /templates/:template_id/share_link' do
    it 'returns success' do
      get "/templates/#{template.id}/share_link"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /templates/:template_id/share_link' do
    it 'updates shared_link and returns ok without redir param' do
      post "/templates/#{template.id}/share_link", params: { template: { shared_link: true } }

      expect(response).to have_http_status(:ok)
      expect(template.reload.shared_link).to be(true)
    end
  end
end
