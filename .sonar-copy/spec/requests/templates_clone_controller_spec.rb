# frozen_string_literal: true

describe 'TemplatesCloneController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }

  before { sign_in user }

  describe 'GET /templates/:template_id/clone/new' do
    it 'returns success for clone form page' do
      get "/templates/#{template.id}/clone/new"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /templates/:template_id/clone' do
    it 'renders unprocessable content when cloned template is invalid' do
      cloned_template = build(:template, account:, author: user)
      allow(Templates::Clone).to receive(:call).and_return(cloned_template)
      allow(cloned_template).to receive(:save).and_return(false)
      allow(Templates).to receive(:maybe_assign_access)

      post "/templates/#{template.id}/clone", params: { template: { name: 'Cloned Name' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
