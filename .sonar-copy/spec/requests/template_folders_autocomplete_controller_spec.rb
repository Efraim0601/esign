# frozen_string_literal: true

describe 'TemplateFoldersAutocompleteController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: User::ADMIN_ROLE) }
  let!(:folder) { create(:template_folder, account:, name: 'Contracts') }
  let!(:subfolder) { create(:template_folder, account:, parent_folder: folder, name: 'NDA') }

  before do
    sign_in user
    create(:template, account:, author: user, folder: subfolder)
  end

  describe 'GET /template_folders_autocomplete' do
    it 'returns matching folders for split query format' do
      get '/template_folders_autocomplete', params: { q: 'Contracts / NDA' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first['full_name']).to include('Contracts')
    end

    it 'returns matching folders using explicit parent_name' do
      get '/template_folders_autocomplete', params: { parent_name: 'Contracts', q: 'NDA' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |e| e['name'] }).to include('NDA')
    end
  end
end
