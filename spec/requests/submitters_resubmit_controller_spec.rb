# frozen_string_literal: true

describe 'SubmittersResubmitController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:other_user) { create(:user, account:, email: 'other@example.test') }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  before { sign_in other_user }

  describe 'PATCH /submitters_resubmit/:id' do
    it 'redirects to submit form when current user email differs from submitter email' do
      patch "/submitters_resubmit/#{submitter.id}"

      expect(response).to redirect_to("/s/#{submitter.slug}")
    end

    it 'creates a new submission copy and redirects to new submitter slug' do
      sign_in author
      submitter.update!(email: author.email, values: { 'field-1' => 'persisted value' })
      submission.update!(template_fields: [{ 'uuid' => 'field-1', 'submitter_uuid' => submitter.uuid, 'type' => 'text' }])

      expect do
        patch "/submitters_resubmit/#{submitter.id}"
      end.to change(Submission, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to include('/s/')
      expect(response.headers['Location']).not_to include("/s/#{submitter.slug}")
    end
  end
end
