# frozen_string_literal: true

describe 'EnquiriesController' do
  describe 'POST /enquiries' do
    before { create(:user) }

    it 'sends sales enquiry when talk_to_sales is enabled' do
      allow(Faraday).to receive(:post)

      post '/enquiries', params: { talk_to_sales: 'on', user: { email: 'lead@example.test' } }

      expect(response).to have_http_status(:ok)
      expect(Faraday).to have_received(:post)
    end

    it 'returns ok without sending when talk_to_sales is not enabled' do
      allow(Faraday).to receive(:post)

      post '/enquiries', params: { talk_to_sales: 'off', user: { email: 'lead@example.test' } }

      expect(response).to have_http_status(:ok)
      expect(Faraday).not_to have_received(:post)
    end
  end
end
