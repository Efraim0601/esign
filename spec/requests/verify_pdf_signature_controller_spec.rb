# frozen_string_literal: true

describe 'VerifyPdfSignatureController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'POST /verify_pdf_signature' do
    it 'renders missing file message when no files are provided' do
      post '/verify_pdf_signature'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('file_is_missing'))
    end
  end
end
