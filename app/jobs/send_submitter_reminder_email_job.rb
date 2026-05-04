# frozen_string_literal: true

class SendSubmitterReminderEmailJob
  include Sidekiq::Job

  def perform(params = {})
    submitter = Submitter.find_by(id: params['submitter_id'])

    return unless submitter
    return if submitter.completed_at?
    return if submitter.declined_at?
    return if submitter.sent_at.blank?
    return if submitter.submission.archived_at?
    return if submitter.template&.archived_at?
    return unless Accounts.can_send_invitation_emails?(submitter.account)

    return unless reminder_still_configured?(submitter, params['duration_key'])

    if SubmissionEvent.exists?(submitter:,
                               event_type: 'send_reminder_email',
                               data: { 'duration_key' => params['duration_key'] })
      return
    end

    mail = SubmitterMailer.invitation_reminder_email(submitter)

    Submitters::ValidateSending.call(submitter, mail)

    mail.deliver_now!

    SubmissionEvent.create!(submitter:,
                            event_type: 'send_reminder_email',
                            data: { 'duration_key' => params['duration_key'] })

    enqueue_form_reminded_webhooks(submitter, params['duration_key'])
  end

  def reminder_still_configured?(submitter, duration_key)
    AccountConfigs.submitter_reminder_offsets(submitter.account).any? { |k, _| k == duration_key }
  end

  def enqueue_form_reminded_webhooks(submitter, duration_key)
    WebhookUrls.for_account_id(submitter.account_id, ['form.reminded']).each do |webhook|
      SendFormRemindedWebhookRequestJob.perform_async(
        'submitter_id' => submitter.id,
        'webhook_url_id' => webhook.id,
        'event_uuid' => SecureRandom.uuid,
        'duration_key' => duration_key
      )
    end
  end
end
