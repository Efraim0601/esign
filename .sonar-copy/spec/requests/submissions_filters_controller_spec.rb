# frozen_string_literal: true

describe 'SubmissionsFiltersController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /submissions_filters/:name' do
    it 'returns not found for unsupported filter name' do
      get '/submissions_filters/unsupported'

      expect(response).to have_http_status(:not_found)
    end
  end
end
