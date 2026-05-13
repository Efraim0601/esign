# frozen_string_literal: true

describe 'TestingAccountsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:testing_user) { build(:user, account:) }

  before { sign_in user }

  describe 'GET /testing_account' do
    it 'impersonates testing user and redirects back fallback' do
      allow(Accounts).to receive(:find_or_create_testing_user).and_return(testing_user)
      allow_any_instance_of(TestingAccountsController).to receive(:impersonate_user)

      get '/testing_account'

      expect(response).to redirect_to('/')
      expect(Accounts).to have_received(:find_or_create_testing_user).with(user.account)
    end
  end

  describe 'DELETE /testing_account' do
    it 'stops impersonation and redirects back fallback' do
      allow_any_instance_of(TestingAccountsController).to receive(:stop_impersonating_user)

      delete '/testing_account'

      expect(response).to redirect_to('/')
    end
  end
end
