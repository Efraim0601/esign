# frozen_string_literal: true

describe 'TemplateFoldersController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:folder) { create(:template_folder, account:, name: 'Contracts') }

  before { sign_in admin }

  describe 'GET /folders/:id' do
    it 'renders folder page' do
      get "/folders/#{folder.id}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /folders/:id' do
    it 'updates folder name and redirects' do
      patch "/folders/#{folder.id}", params: { template_folder: { name: 'Updated Contracts' } }

      expect(response).to redirect_to("/folders/#{folder.id}")
      expect(folder.reload.name).to eq('Updated Contracts')
    end
  end
end
