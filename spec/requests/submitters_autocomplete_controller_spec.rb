# frozen_string_literal: true

describe 'SubmittersAutocompleteController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: :admin) }

  before { sign_in user }

  describe 'GET /submitters_autocomplete' do
    let(:template) { create(:template, account:, author: user, only_field_types: %w[text]) }
    let(:submission) { create(:submission, template:, created_by_user: user) }

    before do
      submission.submitters.create!(uuid: template.submitters.first['uuid'],
                                    account_id: account.id,
                                    email: 'alice@example.test', name: 'Alice')
      submission.submitters.create!(uuid: SecureRandom.uuid,
                                    account_id: account.id,
                                    email: 'bob@example.test', name: 'Bob')
    end

    it 'returns full submitter rows when no field is specified' do
      get '/submitters_autocomplete', params: { q: 'alice' }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.first.keys).to match_array(%w[email phone name])
    end

    it 'returns max-ids grouped results when field=email is specified' do
      get '/submitters_autocomplete', params: { field: 'email', q: 'al' }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to be_an(Array)
    end

    it 'rejects unknown field by ignoring it (falls back to no field branch)' do
      get '/submitters_autocomplete', params: { field: 'unknown', q: 'a' }

      expect(response).to have_http_status(:ok)
    end

    it 'uses fulltext search field branch when fulltext is enabled' do
      allow(Docuseal).to receive(:fulltext_search?).and_return(true)
      allow(Submitters).to receive(:fulltext_search_field).and_return(Submitter.where(id: -1))

      get '/submitters_autocomplete', params: { field: 'name', q: 'ali' }

      expect(Submitters).to have_received(:fulltext_search_field)
      expect(response).to have_http_status(:ok)
    end
  end
end
