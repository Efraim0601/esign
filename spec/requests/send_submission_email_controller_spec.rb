# frozen_string_literal: true

describe 'SendSubmissionEmailController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, template:, created_by_user: author) }
  let!(:submitter) do
    submission.submitters.create!(uuid: template.submitters.first['uuid'],
                                  account_id: account.id,
                                  email: 'completed@example.test',
                                  completed_at: Time.current)
  end

  describe 'POST /send_submission_email' do
    it 'enqueues documents_copy_email when using template_slug + email' do
      mail = double('mail')
      allow(SubmitterMailer).to receive(:documents_copy_email).and_return(mail)
      allow(mail).to receive(:deliver_later!)

      post '/send_submission_email', params: { template_slug: template.slug, email: 'completed@example.test' }

      expect(response).to have_http_status(:ok)
      expect(SubmitterMailer).to have_received(:documents_copy_email)
    end

    it 'redirects to preview completed with error status when submission_slug has no completed submitter' do
      post '/send_submission_email',
           params: { submission_slug: submission.slug, email: 'unknown@example.test' }

      expect(response).to redirect_to(submissions_preview_completed_path(submission.slug, status: :error))
    end

    it 'sends email when found by submitter_slug' do
      mail = double('mail')
      allow(SubmitterMailer).to receive(:documents_copy_email).and_return(mail)
      allow(mail).to receive(:deliver_later!)

      post '/send_submission_email', params: { submitter_slug: submitter.slug }

      expect(response).to have_http_status(:ok)
    end

    it 'skips sending when account is archived' do
      account.update!(archived_at: Time.current)
      allow(SubmitterMailer).to receive(:documents_copy_email)

      post '/send_submission_email', params: { submitter_slug: submitter.slug }

      expect(SubmitterMailer).not_to have_received(:documents_copy_email)
    end

    it 'skips sending when a recent send EmailEvent exists' do
      allow(EmailEvent).to receive(:exists?).and_return(true)
      allow(SubmitterMailer).to receive(:documents_copy_email)

      post '/send_submission_email', params: { submitter_slug: submitter.slug }

      expect(SubmitterMailer).not_to have_received(:documents_copy_email)
    end

    it 'returns 404 when no submitter is found for given submitter_slug' do
      expect do
        post '/send_submission_email', params: { submitter_slug: 'nonexistent-slug' }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
