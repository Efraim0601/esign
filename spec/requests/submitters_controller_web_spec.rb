# frozen_string_literal: true

describe 'SubmittersController (web)' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, author: admin) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: admin) }
  let(:submitter) { submission.submitters.first }

  before { sign_in admin }

  describe 'PATCH /submitters/:id' do
    it 'rejects update when start_form event already exists' do
      create(:submission_event, submitter:, submission:, event_type: 'start_form')

      patch "/submitters/#{submitter.id}", params: { submitter: { email: 'new@example.test' } }

      expect(response).to redirect_to("/submissions/#{submission.id}")
      expect(submitter.reload.email).not_to eq('new@example.test')
    end

    it 'rejects update when all submitter fields are blank' do
      patch "/submitters/#{submitter.id}", params: { submitter: { email: ' ', name: ' ', phone: ' ' } }

      expect(response).to redirect_to("/submissions/#{submission.id}")
    end

    it 'updates submitter and may enqueue notifications' do
      allow(Submitters).to receive(:normalize_preferences).and_return({})
      allow(SearchEntries).to receive(:enqueue_reindex)
      allow(SendSubmitterInvitationEmailJob).to receive(:perform_async)

      patch "/submitters/#{submitter.id}",
            params: {
              submitter: { email: 'updated@example.test', phone: ' +33 6 10 10 10 10 ', name: 'Updated Name' },
              send_email: '1',
              send_sms: '0'
            }

      expect(response).to redirect_to("/submissions/#{submission.id}")
      submitter.reload
      expect(submitter.email).to eq('updated@example.test')
      expect(submitter.phone).to eq('+33610101010')
      expect(submitter.name).to eq('Updated Name')
      expect(SearchEntries).to have_received(:enqueue_reindex).with(submitter)
    end
  end
end
