# frozen_string_literal: true

class ChainSubmitController < ApplicationController
  layout 'form'

  around_action :with_browser_locale, only: %i[new create]
  skip_before_action :authenticate_user!
  skip_authorization_check

  before_action :load_submission
  before_action :authorize_chain_link!

  RATE_LIMIT = 5
  RATE_TTL   = 10.minutes

  def new
    @error_message = flash[:chain_error]
  end

  def create
    enforce_rate_limit!

    email = Submissions.normalize_email(params[:email])

    submitter = @submission.submitters.find_by(email: email) if email.present?

    log_attempt(submitter, email)

    if submitter.nil?
      flash[:chain_error] = I18n.t(:chain_email_not_found)
      redirect_to chain_submit_path(slug: @submission.slug) and return
    end

    if submitter.completed_at?
      redirect_to submit_form_completed_path(submitter.slug) and return
    end

    if submitter.declined_at?
      flash[:chain_error] = I18n.t(:form_has_been_declined)
      redirect_to chain_submit_path(slug: @submission.slug) and return
    end

    if @submission.submitters_order_preserved? && !Submitters.current_submitter_order?(submitter)
      @awaiting_submitter = submitter
      render :awaiting, status: :forbidden and return
    end

    redirect_to submit_form_path(submitter.slug)
  rescue RateLimit::LimitApproached
    flash[:chain_error] = I18n.t(:too_many_attempts)
    redirect_to chain_submit_path(slug: @submission.slug)
  end

  private

  def load_submission
    @submission = Submission.find_by!(slug: params[:slug])
  end

  def authorize_chain_link!
    return if @submission.preferences['chain_link_enabled'] == true &&
              !@submission.archived_at? && !@submission.expired?

    raise ActionController::RoutingError, I18n.t('not_found')
  end

  def enforce_rate_limit!
    RateLimit.call("chain_submit:#{request.remote_ip}:#{@submission.slug}",
                   limit: RATE_LIMIT, ttl: RATE_TTL, enabled: true)
  end

  def log_attempt(submitter, email)
    SubmissionEvent.create!(
      submission: @submission,
      submitter: submitter,
      event_type: 'chain_link_resolve',
      data: {
        ip: request.remote_ip,
        ua: request.user_agent,
        email_tried: email.to_s.presence,
        resolved: submitter.present?
      }.compact_blank
    )
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    Rollbar.warning(e) if defined?(Rollbar)
  end
end
