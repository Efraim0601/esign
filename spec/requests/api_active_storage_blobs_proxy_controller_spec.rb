# frozen_string_literal: true

describe 'Api::ActiveStorageBlobsProxyController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:blob) { template.documents.first.blob }

  describe 'GET /file/:signed_uuid/*filename' do
    it 'returns not found when verifier payload is invalid' do
      allow(ApplicationRecord.signed_id_verifier).to receive(:verified).and_return([nil, 'invalid', nil])

      get '/file/token/sample.pdf'

      expect(response).to have_http_status(:not_found)
    end

    it 'serves byte ranges when range header is present' do
      allow(ApplicationRecord.signed_id_verifier).to receive(:verified).and_return([blob.uuid, 'blob', Time.current.to_i + 3600])
      allow_any_instance_of(Api::ActiveStorageBlobsProxyController).to receive(:send_blob_byte_range_data) do |controller, *_args|
        controller.head :ok
      end

      get '/file/token/sample.pdf', headers: { 'Range' => 'bytes=0-10' }

      expect(response).to have_http_status(:ok)
    end

    it 'streams blob when no range header is provided' do
      allow(ApplicationRecord.signed_id_verifier).to receive(:verified).and_return([blob.uuid, 'blob', Time.current.to_i + 3600])
      allow_any_instance_of(Api::ActiveStorageBlobsProxyController).to receive(:http_cache_forever).and_yield
      allow_any_instance_of(Api::ActiveStorageBlobsProxyController).to receive(:send_blob_stream) do |controller, *_args|
        controller.head :ok
      end

      get '/file/token/sample.pdf'

      expect(response).to have_http_status(:ok)
    end
  end
end
