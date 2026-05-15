# frozen_string_literal: true

describe 'StartFormController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }

  describe 'GET /d/:slug' do
    it 'returns not found when template requires phone/email 2fa for link start' do
      template = create(:template, account:, author:, shared_link: true,
                                   preferences: { 'require_phone_2fa' => true })

      expect do
        get "/d/#{template.slug}"
      end.to raise_error(ActionController::RoutingError)
    end

    it 'returns not found when template is not shared' do
      template = create(:template, account:, author:, shared_link: false, preferences: {})

      expect do
        get "/d/#{template.slug}"
      end.to raise_error(ActionController::RoutingError)
    end

    it 'renders private page for authorized signed-in user on non-shared template' do
      template = create(:template, account:, author:, shared_link: false, preferences: {})
      sign_in author

      get "/d/#{template.slug}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders email verification step for shared template when requested' do
      template = create(:template, account:, author:, shared_link: true, preferences: {})

      get "/d/#{template.slug}", params: { email_verification: '1' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /d/:slug/completed' do
    it 'redirects to start form when template is not shared' do
      template = create(:template, account:, author:, shared_link: false, preferences: {})

      get "/d/#{template.slug}/completed"

      expect(response).to redirect_to("/d/#{template.slug}")
    end

    it 'returns not found when required completion params are missing' do
      template = create(:template, account:, author:, shared_link: true, preferences: {})

      expect do
        get "/d/#{template.slug}/completed"
      end.to raise_error(ActionController::RoutingError)
    end

    it 'returns success when completed submitter exists for required params' do
      template = create(:template, account:, author:, shared_link: true, preferences: {})
      submission = create(:submission, template:, created_by_user: author)
      create(:submitter, submission:, account: account, email: 'done@example.test', completed_at: Time.current)

      get "/d/#{template.slug}/completed", params: { email: 'done@example.test' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /d/:slug' do
    it 'creates submitter and redirects to submit form for shared template' do
      template = create(:template, account:, author:, shared_link: true, preferences: {})

      expect do
        patch "/d/#{template.slug}", params: { submitter: { email: 'new@example.test', name: 'New Signer' } }
      end.to change(Submitter, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to include('/s/')
    end

    it 'redirects to start form when template is archived' do
      template = create(:template, account:, author:, shared_link: true, preferences: {}, archived_at: Time.current)

      patch "/d/#{template.slug}"

      expect(response).to redirect_to("/d/#{template.slug}")
    end
  end
end
