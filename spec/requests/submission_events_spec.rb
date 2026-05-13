# frozen_string_literal: true

describe 'Submission Events API' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }

  describe 'GET /api/events/submission/:type' do
    it 'returns 401 when no auth token is provided' do
      get '/api/events/submission/completed'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns an empty list when no submissions are fully completed' do
      create(:submission, :with_submitters, template:, created_by_user: author)

      get '/api/events/submission/completed', headers: { 'x-auth-token': author.access_token.token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']).to eq([])
      expect(response.parsed_body['pagination']).to include('count' => 0)
    end

    it 'returns events only when every submitter on the submission is completed' do
      submission = create(:submission, :with_submitters, template:, created_by_user: author)
      submission.submitters.update_all(completed_at: 1.hour.ago)

      get '/api/events/submission/completed', headers: { 'x-auth-token': author.access_token.token }

      expect(response).to have_http_status(:ok)
      data = response.parsed_body['data']
      expect(data.size).to eq(1)
      expect(data.first['event_type']).to eq('submission.completed')
      expect(data.first['timestamp']).to be_present
      expect(response.parsed_body['pagination']['count']).to eq(1)
    end
  end
end
