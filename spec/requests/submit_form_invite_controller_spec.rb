# frozen_string_literal: true

describe 'SubmitFormInviteController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, template:, created_by_user: author) }
  let!(:submitter) { create(:submitter, submission:, uuid: 'u1', account:, email: 'owner@example.test') }

  before do
    submission.update!(template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2', 'invite_by_uuid' => 'u1' }])
    allow(Submitters::AuthorizedForForm).to receive(:call).and_return(true)
  end

  describe 'POST /s/:submit_form_slug/invite' do
    it 'returns unprocessable when submitter is not authorized to invite' do
      allow(Submitters::AuthorizedForForm).to receive(:call).and_return(false)

      post "/s/#{submitter.slug}/invite",
           params: { submission: { submitters: [{ uuid: 'u2', email: 'new-signer@example.test' }] } },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'creates invited submitter and marks current submitter as completed' do
      allow(Submitters::SubmitValues).to receive(:call)

      post "/s/#{submitter.slug}/invite",
           params: { submission: { submitters: [{ uuid: 'u2', email: 'new-signer@example.test' }] } },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(submission.submitters.where(uuid: 'u2').count).to eq(1)
      expect(Submitters::SubmitValues).to have_received(:call).with(submitter, kind_of(ActionController::Parameters), kind_of(ActionDispatch::Request))
    end

    it 'returns unprocessable when mandatory invitees are still missing' do
      post "/s/#{submitter.slug}/invite",
           params: { submission: { submitters: [{ uuid: 'u2', email: '' }] } },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
