# frozen_string_literal: true

describe 'UsersController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }

  before { sign_in admin }

  describe 'GET /settings/users' do
    it 'returns success for default active users view' do
      get '/settings/users'

      expect(response).to have_http_status(:ok)
    end

    it 'returns success for archived users status filter' do
      get '/settings/users/archived'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /users/:id/reactivate' do
    it 'reactivates archived user and redirects back to settings users' do
      archived_user = create(:user, account:, archived_at: 1.day.ago)

      patch "/users/#{archived_user.id}/reactivate"

      expect(response).to redirect_to('/settings/users')
      expect(archived_user.reload.archived_at).to be_nil
    end
  end

  describe 'POST /users' do
    it 'creates user and sends invitation email' do
      mail = double('mail', deliver_later!: true)
      allow(UserMailer).to receive(:invitation_email).and_return(mail)

      expect do
        post '/users', params: {
          user: {
            email: 'new-user@example.test',
            first_name: 'New',
            last_name: 'User',
            role: 'member'
          }
        }
      end.to change(User, :count).by(1)

      created_user = User.order(:id).last
      expect(UserMailer).to have_received(:invitation_email).with(created_user)
      expect(mail).to have_received(:deliver_later!)
      expect(response).to redirect_to('/settings/users')
    end
  end

  describe 'PATCH /users/:id' do
    it 'updates editable fields and redirects back' do
      target = create(:user, account:, first_name: 'Old', last_name: 'Name', role: 'member')

      patch "/users/#{target.id}", params: { user: { first_name: 'Updated', last_name: 'Person' } }

      expect(response).to redirect_to('/settings/users')
      expect(target.reload.first_name).to eq('Updated')
      expect(target.last_name).to eq('Person')
    end
  end

  describe 'DELETE /users/:id' do
    it 'archives non-current user' do
      target = create(:user, account:)

      delete "/users/#{target.id}"

      expect(response).to redirect_to('/settings/users')
      expect(target.reload.archived_at).not_to be_nil
    end

    it 'does not allow deleting current user' do
      delete "/users/#{admin.id}"

      expect(response).to redirect_to('/settings/users')
      expect(admin.reload.archived_at).to be_nil
    end
  end
end
