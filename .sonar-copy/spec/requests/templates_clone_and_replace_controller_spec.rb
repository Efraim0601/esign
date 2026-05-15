# frozen_string_literal: true

describe 'TemplatesCloneAndReplaceController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }

  before { sign_in author }

  def uploaded_pdf(name = 'replacement.pdf')
    tempfile = Tempfile.new([File.basename(name, '.pdf'), '.pdf'])
    tempfile.binmode
    tempfile.write('%PDF-1.4 test')
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, 'application/pdf', true, original_filename: name)
  end

  describe 'POST /templates/:template_id/clone_and_replace' do
    it 'returns unprocessable when files param is missing' do
      post "/templates/#{template.id}/clone_and_replace"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'clones, replaces documents, and redirects to edit page' do
      file = uploaded_pdf
      cloned_template = create(:template, account:, author:)
      replaced_document = double('doc', uuid: 'new-doc-uuid')

      allow(ActiveRecord::Associations::Preloader).to receive(:new).and_return(double(call: true))
      allow(Templates::Clone).to receive(:call).and_return(cloned_template)
      allow(Templates::ReplaceAttachments).to receive(:call).and_return([replaced_document])
      allow(Templates).to receive(:maybe_assign_access)
      allow(Templates::CloneAttachments).to receive(:call)
      allow(SearchEntries).to receive(:enqueue_reindex)

      post "/templates/#{template.id}/clone_and_replace", params: { files: [file] }

      expect(response).to redirect_to("/templates/#{cloned_template.id}/edit")
      expect(Templates::Clone).to have_received(:call).with(template, author: author)
      expect(Templates::ReplaceAttachments).to have_received(:call).with(cloned_template, kind_of(ActionController::Parameters),
                                                                         extract_fields: true)
      expect(Templates::CloneAttachments).to have_received(:call)
      expect(SearchEntries).to have_received(:enqueue_reindex).with(cloned_template)
    end
  end
end
