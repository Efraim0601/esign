# frozen_string_literal: true

describe 'Api::AttachmentsController' do
  describe 'POST /api/attachments' do
    it 'creates attachment and renders serialized payload' do
      submitter = double('submitter', email: 's@example.test')
      attachment_payload = {
        'uuid' => 'att-1',
        'created_at' => Time.current.as_json,
        'url' => 'https://files.test/att-1',
        'filename' => 'file.png',
        'content_type' => 'image/png'
      }
      attachment = double('attachment')

      allow(Submitter).to receive(:find_by!).with(slug: 'sub-1').and_return(submitter)
      allow(Submitters).to receive(:create_attachment!).and_return(attachment)
      allow(attachment).to receive(:as_json).and_return(attachment_payload)

      post '/api/attachments', params: { submitter_slug: 'sub-1', type: 'file' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('uuid' => 'att-1', 'filename' => 'file.png')
    end

    it 'returns unprocessable content when malicious extension is detected' do
      submitter = double('submitter', email: 's@example.test')
      allow(Submitter).to receive(:find_by!).and_return(submitter)
      allow(Submitters).to receive(:create_attachment!)
        .and_raise(Submitters::MaliciousFileExtension.new('invalid extension'))

      post '/api/attachments', params: { submitter_slug: 'sub-1', type: 'file' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('invalid extension')
    end
  end
end
