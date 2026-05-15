# frozen_string_literal: true

describe 'TemplatesFoldersController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:new_folder) { create(:template_folder, account:, author: user, name: 'Contracts') }

  before { sign_in user }

  describe 'PATCH /templates/:template_id/folder' do
    it 'moves template to resolved folder and redirects back fallback' do
      allow(TemplateFolders).to receive(:find_or_create_by_name).and_return(new_folder)

      patch "/templates/#{template.id}/folder", params: { name: 'Contracts' }

      expect(response).to redirect_to("/templates/#{template.id}")
      expect(TemplateFolders).to have_received(:find_or_create_by_name).with(user, 'Contracts')
      expect(template.reload.folder_id).to eq(new_folder.id)
    end
  end
end
