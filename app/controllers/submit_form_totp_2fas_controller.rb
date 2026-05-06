# frozen_string_literal: true

class SubmitFormTotp2fasController < ApplicationController
  around_action :with_browser_locale

  skip_before_action :authenticate_user!
  skip_authorization_check

  before_action :load_submitter

  COOKIES_TTL = 12.hours
  COOKIES_DEFAULTS = { httponly: true, secure: Rails.env.production? }.freeze

  def create
    RateLimit.call("verify-totp-#{@submitter.id}", limit: 5, ttl: 45.seconds, enabled: true)

    user = Submitters::AuthorizedForForm.totp_user_for(@submitter)

    return render_invalid unless user

    if user.validate_and_consume_otp!(params[:otp_attempt].to_s.gsub(/\D/, ''))
      SubmissionEvents.create_with_tracking_data(@submitter, 'email_verified', request, { email: @submitter.email })

      cookies.encrypted[:email_2fa_slug] =
        { value: @submitter.slug, expires: COOKIES_TTL.from_now, **COOKIES_DEFAULTS }

      redirect_to submit_form_path(@submitter.slug)
    else
      render_invalid
    end
  rescue RateLimit::LimitApproached
    redirect_to submit_form_path(@submitter.slug, status: :error), alert: I18n.t(:too_many_attempts)
  end

  def load_submitter
    @submitter = Submitter.find_by!(slug: params[:submitter_slug])
  end

  def render_invalid
    redirect_to submit_form_path(@submitter.slug, status: :error), alert: I18n.t(:invalid_code)
  end
end
