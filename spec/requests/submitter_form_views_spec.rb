# frozen_string_literal: true

describe 'Submitter Form Views API' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  describe 'POST /api/submitter_form_views' do
    it 'records the form view event and updates opened_at' do
      submitter.update_column(:opened_at, nil)
      allow(SubmissionEvents).to receive(:create_with_tracking_data)
      allow(WebhookUrls).to receive(:enqueue_events)

      freeze_time do
        post '/api/submitter_form_views', params: { submitter_slug: submitter.slug }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({})
        expect(submitter.reload.opened_at).to be_within(1.second).of(Time.current)
        expect(SubmissionEvents).to have_received(:create_with_tracking_data).with(submitter, 'view_form', kind_of(ActionDispatch::Request))
        expect(WebhookUrls).to have_received(:enqueue_events).with(submitter, 'form.viewed')
      end
    end

    it 'returns 404 when the submitter slug is unknown' do
      expect do
        post '/api/submitter_form_views', params: { submitter_slug: 'no-such-slug' }, as: :json
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'enqueues a form.viewed webhook' do
      allow(WebhookUrls).to receive(:enqueue_events)

      post '/api/submitter_form_views', params: { submitter_slug: submitter.slug }, as: :json

      expect(WebhookUrls).to have_received(:enqueue_events).with(submitter, 'form.viewed')
    end
  end
end
