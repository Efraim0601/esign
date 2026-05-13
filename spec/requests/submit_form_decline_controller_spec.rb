# frozen_string_literal: true

describe 'SubmitFormDeclineController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  describe 'POST /s/:submit_form_slug/decline' do
    it 'redirects back when user is not authorized for the form' do
      allow(Submitters::AuthorizedForForm).to receive(:call).and_return(false)

      post "/s/#{submitter.slug}/decline", params: { reason: 'No' }

      expect(response).to redirect_to("/s/#{submitter.slug}")
      expect(submitter.reload.declined_at).to be_nil
    end

    it 'declines submitter, sends notification and enqueues webhook' do
      mail = double('mail', deliver_later!: true)
      allow(Submitters::AuthorizedForForm).to receive(:call).and_return(true)
      allow(SubmissionEvents).to receive(:create_with_tracking_data)
      allow(SubmitterMailer).to receive(:declined_email).and_return(mail)
      allow(WebhookUrls).to receive(:enqueue_events)

      post "/s/#{submitter.slug}/decline", params: { reason: 'Decline reason' }

      expect(response).to redirect_to("/s/#{submitter.slug}")
      expect(submitter.reload.declined_at).not_to be_nil
      expect(SubmissionEvents).to have_received(:create_with_tracking_data)
      expect(WebhookUrls).to have_received(:enqueue_events).with(submitter, 'form.declined')
    end
  end
end
