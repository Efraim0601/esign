# frozen_string_literal: true

describe 'TemplatesController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, preferences: { 'is_draft' => true }) }

  before { sign_in author }

  describe 'GET /templates/:id' do
    it 'returns success' do
      get "/templates/#{template.id}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /templates/:id' do
    it 'updates name and removes draft flag when publish is true' do
      patch "/templates/#{template.id}",
            params: { template: { name: 'Published Template' }, publish: 'true' }

      expect(response).to have_http_status(:ok)
      expect(template.reload.name).to eq('Published Template')
      expect(template.reload.preferences).not_to have_key('is_draft')
    end
  end

  describe 'DELETE /templates/:id' do
    it 'archives template when permanently flag is not set' do
      delete "/templates/#{template.id}"

      expect(response).to have_http_status(:found)
      expect(template.reload.archived_at).not_to be_nil
    end
  end
end
