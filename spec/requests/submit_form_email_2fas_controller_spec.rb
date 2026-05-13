# frozen_string_literal: true

describe 'SubmitFormEmail2fasController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, submitter_count: 0, attachment_count: 0) }
  let(:submission) { create(:submission, template:, created_by_user: author) }
  let(:submitter) { create(:submitter, submission:, account:, email: 'sig@example.test') }

  describe 'POST /submit_form_email_2fa (verify code)' do
    it 'verifies code, sets cookie, and redirects to submit form' do
      allow(EmailVerificationCodes).to receive(:verify).and_return(true)

      post '/submit_form_email_2fa', params: { submitter_slug: submitter.slug, one_time_code: '123456' }

      expect(response).to redirect_to("/s/#{submitter.slug}")
      expect(submitter.submission_events.where(event_type: 'email_verified')).to exist
    end

    it 'redirects with alert when code is invalid' do
      allow(EmailVerificationCodes).to receive(:verify).and_return(false)

      post '/submit_form_email_2fa', params: { submitter_slug: submitter.slug, one_time_code: 'bad' }

      expect(response).to redirect_to("/s/#{submitter.slug}?status=error")
      expect(flash[:alert]).not_to be_blank
    end

    it 'redirects with rate limit alert when too many attempts' do
      allow(RateLimit).to receive(:call).and_raise(RateLimit::LimitApproached)

      post '/submit_form_email_2fa', params: { submitter_slug: submitter.slug, one_time_code: '000' }

      expect(response).to redirect_to("/s/#{submitter.slug}?status=error")
    end
  end

  describe 'PATCH /submit_form_email_2fa (send code)' do
    it 'enqueues verification email and redirects on first call' do
      allow(SendSubmitterVerificationEmailJob).to receive(:perform_async)

      patch '/submit_form_email_2fa', params: { submitter_slug: submitter.slug }

      expect(SendSubmitterVerificationEmailJob).to have_received(:perform_async).with(
        hash_including('submitter_id' => submitter.id)
      )
      expect(response).to redirect_to("/s/#{submitter.slug}?status=sent")
    end

    it 'sets resent alert when resend param is set' do
      allow(SendSubmitterVerificationEmailJob).to receive(:perform_async)

      patch '/submit_form_email_2fa', params: { submitter_slug: submitter.slug, resend: '1' }

      expect(flash[:alert]).not_to be_blank
    end

    it 'rate-limits send within 15 seconds of last event' do
      submitter.submission_events.create!(event_type: 'send_2fa_email')

      patch '/submit_form_email_2fa', params: { submitter_slug: submitter.slug }

      expect(response).to redirect_to("/s/#{submitter.slug}?status=error")
    end

    it 'redirects with rate-limit alert when limit approached' do
      allow(RateLimit).to receive(:call).and_raise(RateLimit::LimitApproached)

      patch '/submit_form_email_2fa', params: { submitter_slug: submitter.slug }

      expect(response).to redirect_to("/s/#{submitter.slug}?status=error")
    end
  end
end
