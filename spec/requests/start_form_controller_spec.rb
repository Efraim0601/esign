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

    it 'sends email 2FA verification code when shared_link_2fa is enabled' do
      template = create(:template, account:, author:, shared_link: true,
                                   preferences: { 'shared_link_2fa' => true })
      allow(Submitters).to receive(:send_shared_link_email_verification_code)
      allow(Submitters).to receive(:verify_link_otp!).and_return(false)

      patch "/d/#{template.slug}", params: { submitter: { email: 'shared@example.test', name: 'Shared' } }

      expect(Submitters).to have_received(:send_shared_link_email_verification_code)
      expect(response).to have_http_status(:ok)
    end

    it 'redirects to submit form when shared_link_2fa cookie is set' do
      template = create(:template, account:, author:, shared_link: true,
                                   preferences: { 'shared_link_2fa' => true })
      submitter = create(:submitter, submission: create(:submission, template:, created_by_user: author),
                                     email: 'cookie@example.test')
      allow(Submitters).to receive(:verify_link_otp!).and_return(true)

      patch "/d/#{template.slug}", params: { submitter: { email: 'cookie@example.test', name: 'Cookie' },
                                             one_time_code: '123456' }

      _ = submitter # keep created
      expect(response).to be_redirect
    end

    it 'redirects with rate limit alert when OTP send fails' do
      template = create(:template, account:, author:, shared_link: true,
                                   preferences: { 'shared_link_2fa' => true })
      allow(Submitters).to receive(:verify_link_otp!).and_return(false)
      allow(Submitters).to receive(:send_shared_link_email_verification_code)
        .and_raise(RateLimit::LimitApproached)

      patch "/d/#{template.slug}", params: { submitter: { email: 'rl@example.test', name: 'RL' } }

      expect(response).to be_redirect
    end

    it 'self-signs using current_user data when selfsign param is set' do
      template = create(:template, account:, author:, shared_link: true, preferences: {})
      sign_in author

      patch "/d/#{template.slug}", params: { selfsign: '1' }

      expect(response).to be_redirect
    end
  end

end
