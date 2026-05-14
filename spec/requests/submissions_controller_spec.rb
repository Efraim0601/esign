# frozen_string_literal: true

describe 'SubmissionsController (web)' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, only_field_types: %w[text]) }

  before { sign_in author }

  describe 'GET /submissions/:id' do
    it 'renders the submission show page' do
      submission = create(:submission, template:, created_by_user: author)
      submission.submitters.create!(uuid: template.submitters.first['uuid'],
                                    account_id: account.id, email: 'someone@example.test')

      get "/submissions/#{submission.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders show page for completed submission with submitter events preloaded' do
      submission = create(:submission, template:, created_by_user: author)
      submission.submitters.create!(uuid: template.submitters.first['uuid'],
                                    account_id: account.id, email: 'done@example.test',
                                    completed_at: Time.current)

      get "/submissions/#{submission.id}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /templates/:template_id/submissions/new' do
    it 'renders the new submission page' do
      get "/templates/#{template.id}/submissions/new"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /templates/:template_id/submissions' do
    it 'creates submissions from emails' do
      allow(SendSubmitterInvitationEmailJob).to receive(:perform_async)

      expect do
        post "/templates/#{template.id}/submissions",
             params: { emails: 'a@example.test, b@example.test', send_email: '0' }
      end.to change(Submission, :count).by(2)

      expect(response).to redirect_to(template_path(template))
    end

    it 'renders error partial when emails creation raises BaseError' do
      allow(Submissions).to receive(:create_from_emails)
        .and_raise(Submissions::CreateFromSubmitters::BaseError.new('Boom'))

      post "/templates/#{template.id}/submissions",
           params: { emails: 'a@example.test' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'saves template message when save_message=1 and is_custom_message=1' do
      post "/templates/#{template.id}/submissions",
           params: { emails: 'x@example.test', save_message: '1', is_custom_message: '1',
                     subject: 'Saved subject', body: 'Saved body' }

      expect(template.reload.preferences['request_email_subject']).to eq('Saved subject')
      expect(template.reload.preferences['request_email_body']).to eq('Saved body')
    end

    it 'renders error response on unexpected StandardError' do
      allow(Submissions).to receive(:create_from_emails).and_raise(StandardError.new('boom-x'))

      post "/templates/#{template.id}/submissions",
           params: { emails: 'a@example.test' }

      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe 'DELETE /submissions/:id' do
    it 'archives the submission softly' do
      submission = create(:submission, template:, created_by_user: author)

      delete "/submissions/#{submission.id}"

      expect(submission.reload.archived_at).not_to be_nil
      expect(response).to be_redirect
    end

    it 'destroys the submission permanently when permanently=true' do
      submission = create(:submission, template:, created_by_user: author)

      delete "/submissions/#{submission.id}?permanently=true"

      expect { submission.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(response).to be_redirect
    end
  end
end
