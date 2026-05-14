# frozen_string_literal: true

describe 'SubmitFormController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  before do
    allow(Submitters::AuthorizedForForm).to receive(:pass_link_2fa?).and_return(true)
    allow(Submitters::AuthorizedForForm).to receive(:pass_email_2fa?).and_return(true)
    allow(Submitters::AuthorizedForForm).to receive(:call).and_return(true)
    allow(Submitters::FormConfigs).to receive(:call).and_return({})
    allow(Submissions).to receive(:preload_with_pages)
    allow(Submitters::MaybeUpdateDefaultValues).to receive(:call)
    allow(Submitters::MaybeAssignDefaultBrowserSignature).to receive(:call).and_return(nil)
    allow(UserConfigs).to receive(:load_signature).and_return(nil)
  end

  describe 'GET /s/:slug' do
    it 'redirects to completed page when submitter already completed' do
      submitter.update!(completed_at: Time.current)

      get "/s/#{submitter.slug}"

      expect(response).to redirect_to("/s/#{submitter.slug}/completed")
    end

    it 'redirects to start form when link 2fa is required' do
      allow(Submitters::AuthorizedForForm).to receive(:pass_link_2fa?).and_return(false)

      get "/s/#{submitter.slug}"

      expect(response).to redirect_to("/d/#{template.slug}")
    end
  end

  describe 'PATCH /s/:slug' do
    it 'returns unprocessable when form authorization fails' do
      allow(Submitters::AuthorizedForForm).to receive(:call).and_return(false)

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns field_uuid payload on required field error' do
      allow(Submitters::SubmitValues).to receive(:call)
        .and_raise(Submitters::SubmitValues::RequiredFieldError.new('field-uuid-1'))

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['field_uuid']).to eq('field-uuid-1')
    end
  end

  describe 'GET /s/:slug/completed' do
    it 'redirects to form page when not authorized on completed route' do
      allow(Submitters::AuthorizedForForm).to receive(:call).and_return(false)

      get "/s/#{submitter.slug}/completed"

      expect(response).to redirect_to("/s/#{submitter.slug}")
    end

    it 'raises not found when account is archived' do
      account.update!(archived_at: Time.current)

      expect do
        get "/s/#{submitter.slug}/completed"
      end.to raise_error(ActionController::RoutingError)
    end
  end

  describe 'GET /s/:slug renders email_2fa when 2fa is required' do
    it 'renders email_2fa partial when pass_email_2fa? is false and no TOTP user' do
      allow(Submitters::AuthorizedForForm).to receive(:pass_email_2fa?).and_return(false)
      allow(Submitters::AuthorizedForForm).to receive(:totp_user_for).and_return(nil)

      get "/s/#{submitter.slug}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to be_blank
    end

    it 'renders totp_2fa when a TOTP user matches the submitter' do
      allow(Submitters::AuthorizedForForm).to receive(:pass_email_2fa?).and_return(false)
      allow(Submitters::AuthorizedForForm).to receive(:totp_user_for).and_return(author)

      get "/s/#{submitter.slug}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /s/:slug locked states' do
    it 'renders archived page when template is archived' do
      template.update!(archived_at: Time.current)

      get "/s/#{submitter.slug}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders declined page when submitter has declined' do
      submitter.update!(declined_at: Time.current)

      get "/s/#{submitter.slug}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders expired page when submission has expired' do
      submission.update!(expire_at: 1.day.ago)

      get "/s/#{submitter.slug}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders awaiting page when enforce_signing_order is set and not current submitter' do
      allow(Submitters::FormConfigs).to receive(:call).and_return({ enforce_signing_order: true })
      allow(Submitters).to receive(:current_submitter_order?).and_return(false)

      get "/s/#{submitter.slug}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /s/:slug error paths' do
    it 'returns error when submitter already completed' do
      submitter.update!(completed_at: Time.current)

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).not_to be_blank
    end

    it 'returns error when submission template is archived' do
      template.update!(archived_at: Time.current)

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns error when submission has expired' do
      allow_any_instance_of(Submission).to receive(:expired?).and_return(true)

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns error when submitter has declined' do
      submitter.update!(declined_at: Time.current)

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 200 OK when SubmitValues succeeds' do
      allow(Submitters::SubmitValues).to receive(:call)

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'returns validation error message on ValidationError' do
      allow(Submitters::SubmitValues).to receive(:call)
        .and_raise(Submitters::SubmitValues::ValidationError.new('Bad value'))

      patch "/s/#{submitter.slug}", params: { values: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('Bad value')
    end
  end
end
