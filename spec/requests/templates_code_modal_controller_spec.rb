# frozen_string_literal: true

describe 'TemplatesCodeModalController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }

  before { sign_in user }

  describe 'GET /templates/:template_id/code_modal' do
    it 'renders successfully' do
      get "/templates/#{template.id}/code_modal"

      expect(response).to have_http_status(:ok)
    end
  end
end
