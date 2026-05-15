# frozen_string_literal: true

describe 'SearchEntriesReindexController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'POST /settings/search_entries_reindex' do
    it 'enqueues full reindex and redirects to account settings' do
      allow(ReindexAllSearchEntriesJob).to receive(:perform_async)

      post '/settings/search_entries_reindex'

      expect(response).to redirect_to('/settings/account')
      expect(ReindexAllSearchEntriesJob).to have_received(:perform_async)
    end
  end
end
