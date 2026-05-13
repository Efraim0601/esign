# frozen_string_literal: true

describe 'Submitter Email Clicks API' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  describe 'POST /api/submitter_email_clicks' do
    it 'creates a click_email event when tracking param matches' do
      tracking = SubmissionEvents.build_tracking_param(submitter, 'click_email')

      expect do
        post '/api/submitter_email_clicks', params: { submitter_slug: submitter.slug, t: tracking }
      end.to change { submitter.submission_events.where(event_type: 'click_email').count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({})
    end

    it 'does not create an event when tracking param does not match' do
      expect do
        post '/api/submitter_email_clicks', params: { submitter_slug: submitter.slug, t: 'wrong' }
      end.not_to(change { submitter.submission_events.where(event_type: 'click_email').count })

      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 when submitter slug is unknown' do
      expect do
        post '/api/submitter_email_clicks', params: { submitter_slug: 'no-such-slug', t: 'whatever' }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
