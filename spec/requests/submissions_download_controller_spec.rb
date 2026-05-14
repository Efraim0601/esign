# frozen_string_literal: true

describe 'SubmissionsDownloadController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  describe 'GET /submitters/:slug/download' do
    it 'returns not found when no completed submitter exists' do
      allow(Submissions::EnsureResultGenerated).to receive(:call)

      get "/submitters/#{submitter.slug}/download"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns urls when current user is allowed to read submitter' do
      sign_in author
      submitter.update!(completed_at: Time.current)
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow(Submitters).to receive(:select_attachments_for_download).with(submitter).and_return([])

      get "/submitters/#{submitter.slug}/download"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it 'returns not found for unauthenticated link request without sig' do
      submitter.update!(completed_at: Time.current)
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow(Submitters::AuthorizedForForm).to receive(:call).and_return(false)

      get "/submitters/#{submitter.slug}/download"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns response when sig is valid (signature_valid bypasses TTL check)' do
      sig = submitter.signed_id(purpose: :download_completed)
      submitter.update!(completed_at: 1.year.ago)
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow(Submitters).to receive(:select_attachments_for_download).and_return([])

      get "/submitters/#{submitter.slug}/download?sig=#{sig}"

      expect(response).to have_http_status(:ok)
    end

    it 'returns combined download URL when combined=true and submitter is the last completed' do
      submitter.update!(completed_at: 1.minute.ago)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('PDF-FAKE'),
        filename: 'combined.pdf',
        content_type: 'application/pdf'
      )
      attachment = ActiveStorage::Attachment.create!(blob:, name: 'combined_document', record: submission)
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow_any_instance_of(Submission).to receive(:combined_document_attachment).and_return(attachment)
      sign_in author

      get "/submitters/#{submitter.slug}/download?combined=true"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end
end
