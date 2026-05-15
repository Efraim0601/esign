# frozen_string_literal: true

describe 'TemplatesDashboardController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }

  before do
    sign_in author
    create(:template, account:, author:, shared_link: true)
  end

  describe 'GET /templates' do
    it 'renders templates dashboard successfully' do
      get '/templates'

      expect(response).to have_http_status(:ok)
    end

    it 'renders successfully with search query' do
      get '/templates', params: { q: 'template' }

      expect(response).to have_http_status(:ok)
    end
  end
end
