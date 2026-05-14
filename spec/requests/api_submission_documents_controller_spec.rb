# frozen_string_literal: true

describe 'Api::SubmissionDocumentsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:access_token) { create(:access_token, user:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }

  describe 'GET /api/submissions/:submission_id/documents' do
    it 'renders serialized document urls for preview documents' do
      filename = double('filename', base: 'doc-1')
      blob = double('blob')
      attachment = double('attachment', filename: filename, blob: blob)

      allow_any_instance_of(Api::SubmissionDocumentsController).to receive(:build_completed_documents).and_return([attachment])
      allow(ActiveRecord::Associations::Preloader).to receive(:new).and_return(double(call: true))
      allow(Accounts).to receive(:link_expires_at).and_return(Time.current + 1.hour)
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(blob, expires_at: kind_of(Time)).and_return('https://files.test/doc-1')

      get "/api/submissions/#{submission.id}/documents", headers: { 'X-Auth-Token' => access_token.token }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(submission.id)
      expect(body['documents'].first).to include('name' => 'doc-1', 'url' => 'https://files.test/doc-1')
    end

    it 'returns merged preview document when ?merge=true and submission has multiple docs' do
      submitter = submission.submitters.create!(uuid: template.submitters.first['uuid'],
                                                account_id: account.id, email: 'pending@example.test')
      _ = submitter

      filename = double('filename', base: 'merged')
      blob = double('blob')
      merged_attachment = double('attachment', filename: filename, blob: blob)
      allow_any_instance_of(Api::SubmissionDocumentsController).to receive(:build_preview_documents).and_return([merged_attachment])
      allow(ActiveRecord::Associations::Preloader).to receive(:new).and_return(double(call: true))
      allow(Accounts).to receive(:link_expires_at).and_return(nil)
      allow(ActiveStorage::Blob).to receive(:proxy_url).and_return('https://files.test/merged.pdf')

      get "/api/submissions/#{submission.id}/documents?merge=true",
          headers: { 'X-Auth-Token' => access_token.token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['documents'].first['name']).to eq('merged')
    end

    it 'raises RecordNotFound for non-existent submission' do
      expect do
        get '/api/submissions/9999999/documents', headers: { 'X-Auth-Token' => access_token.token }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'private helpers' do
    let(:controller) { Api::SubmissionDocumentsController.new }

    describe '#build_completed_documents' do
      it 'returns the existing merged_document_attachment when merge=true and present' do
        existing = double('merged')
        submission_dbl = double('submission',
                                merged_document_attachment: existing,
                                submitters: [double('submitter', completed_at: Time.current)])

        result = controller.send(:build_completed_documents, submission_dbl, merge: true)

        expect(result).to eq([existing])
      end

      it 'returns documents_attachments when merge=false and they exist' do
        attachments = [double('doc1'), double('doc2')]
        submitter = double('submitter', completed_at: Time.current, documents_attachments: attachments)
        submission_dbl = double('submission', submitters: [submitter])

        result = controller.send(:build_completed_documents, submission_dbl, merge: false)

        expect(result).to eq(attachments)
      end

      it 'generates result attachments when no documents_attachments exist' do
        submitter = double('submitter', completed_at: Time.current, documents_attachments: [])
        allow(submitter).to receive(:documents_attachments=)
        submission_dbl = double('submission', submitters: [submitter])
        allow(Submissions::EnsureResultGenerated).to receive(:call).with(submitter).and_return([:generated])

        controller.send(:build_completed_documents, submission_dbl, merge: false)

        expect(submitter).to have_received(:documents_attachments=).with([:generated])
      end
    end

    describe '#build_preview_documents' do
      it 'returns cached preview when values_hash matches' do
        preview = double('attachment', metadata: { 'values_hash' => 'abc' })
        submission_dbl = double('submission', preview_documents: [preview], preview_merged_document_attachment: nil)
        allow(Submissions::GeneratePreviewAttachments).to receive(:build_values_hash).and_return('abc')

        result = controller.send(:build_preview_documents, submission_dbl, merge: false)

        expect(result).to eq([preview])
      end

      it 'rebuilds preview when values_hash mismatches' do
        stale = double('stale', metadata: { 'values_hash' => 'old' })
        allow(stale).to receive(:destroy)
        submission_dbl = double('submission', preview_documents: [stale])
        allow(Submissions::GeneratePreviewAttachments).to receive(:build_values_hash).and_return('new')
        allow(Submissions::GeneratePreviewAttachments).to receive(:call).and_return([:fresh])
        allow(ApplicationRecord).to receive(:no_touching).and_yield

        result = controller.send(:build_preview_documents, submission_dbl, merge: false)

        expect(result).to eq([:fresh])
      end
    end
  end
end
