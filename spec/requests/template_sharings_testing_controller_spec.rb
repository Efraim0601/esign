# frozen_string_literal: true

describe 'TemplateSharingsTestingController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:testing_user) { build(:user, account:) }

  before { sign_in user }

  describe 'POST /template_sharings_testing' do
    it 'creates sharing when value is 1' do
      allow(Accounts).to receive(:find_or_create_testing_user).and_return(testing_user)

      expect do
        post '/template_sharings_testing', params: { template_id: template.id, value: '1' }
      end.to change(TemplateSharing, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it 'removes sharing when value is 0' do
      TemplateSharing.create!(template:, account:, ability: :manage)
      allow(Accounts).to receive(:find_or_create_testing_user).and_return(double(account:))

      expect do
        post '/template_sharings_testing', params: { template_id: template.id, value: '0' }
      end.to change(TemplateSharing, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
