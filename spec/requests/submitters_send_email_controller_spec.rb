# frozen_string_literal: true

describe 'SubmittersSendEmailController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: user) }
  let(:submitter) { submission.submitters.first }

  before { sign_in user }

  describe 'POST /submitters/:submitter_slug/send_email' do
    it 'enqueues invitation email and sets sent_at' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(SendSubmitterInvitationEmailJob).to receive(:perform_async)
      submitter.update_column(:sent_at, nil)

      post "/submitters/#{submitter.slug}/send_email"

      expect(response).to redirect_to("/submissions/#{submission.id}")
      expect(SendSubmitterInvitationEmailJob).to have_received(:perform_async).with('submitter_id' => submitter.id)
      expect(submitter.reload.sent_at).not_to be_nil
    end
  end
end
