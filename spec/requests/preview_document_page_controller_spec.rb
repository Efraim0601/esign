# frozen_string_literal: true

describe 'PreviewDocumentPageController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }

  describe 'GET /preview/:signed_key' do
    it 'returns not found for invalid signed key' do
      get '/preview/invalid-key/1'

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found when signed_key resolves but attachment is missing' do
      key = ApplicationRecord.signed_id_verifier.generate(SecureRandom.uuid, purpose: :attachment)

      get "/preview/#{key}/0"

      expect(response).to have_http_status(:not_found)
    end

    it 'redirects to preview image url when one already exists for the requested page' do
      attachment = template.documents.first

      # Create a preview image attachment with the expected filename
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('PNG-FAKE'),
        filename: '0.png',
        content_type: 'image/png',
        metadata: { width: 100, height: 100 }
      )
      ActiveStorage::Attachment.create!(blob:, name: 'preview_images', record: attachment)

      key = ApplicationRecord.signed_id_verifier.generate(attachment.uuid, purpose: :attachment)

      get "/preview/#{key}/0"

      expect(response).to be_redirect
    end

    it 'verifies an [id, uuid] array signed payload' do
      attachment = template.documents.first
      key = ApplicationRecord.signed_id_verifier.generate([attachment.id, attachment.uuid], purpose: :attachment)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('PNG-FAKE'),
        filename: '0.png',
        content_type: 'image/png',
        metadata: { width: 100, height: 100 }
      )
      ActiveStorage::Attachment.create!(blob:, name: 'preview_images', record: attachment)

      get "/preview/#{key}/0"

      expect(response).to be_redirect
    end
  end
end
