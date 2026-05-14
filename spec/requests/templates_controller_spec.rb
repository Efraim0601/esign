# frozen_string_literal: true

describe 'TemplatesController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, preferences: { 'is_draft' => true }) }

  before { sign_in author }

  describe 'GET /templates/:id' do
    it 'returns success' do
      get "/templates/#{template.id}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /templates/:id' do
    it 'updates name and removes draft flag when publish is true' do
      patch "/templates/#{template.id}",
            params: { template: { name: 'Published Template' }, publish: 'true' }

      expect(response).to have_http_status(:ok)
      expect(template.reload.name).to eq('Published Template')
      expect(template.reload.preferences).not_to have_key('is_draft')
    end
  end

  describe 'DELETE /templates/:id' do
    it 'archives template when permanently flag is not set' do
      delete "/templates/#{template.id}"

      expect(response).to have_http_status(:found)
      expect(template.reload.archived_at).not_to be_nil
    end

    it 'returns redirect after archive update' do
      delete "/templates/#{template.id}"

      expect(response).to be_redirect
    end
  end

  describe 'POST /templates' do
    it 'creates a new template via TemplateFolders helper' do
      allow(SearchEntries).to receive(:enqueue_reindex)
      allow(WebhookUrls).to receive(:enqueue_events)

      expect do
        post '/templates',
             params: { template: { name: 'New Template' }, folder_name: 'My Folder' }
      end.to change(Template, :count).by(1)

      expect(response).to be_redirect
      created = Template.last
      expect(created.author).to eq(author)
      expect(created.folder.name).to eq('My Folder')
    end

    it 'renders unprocessable_content when template fails to save' do
      allow_any_instance_of(Template).to receive(:save).and_return(false)

      post '/templates', params: { template: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /templates/:id triggers reindex on name change' do
    it 'enqueues search reindex when name changes' do
      allow(SearchEntries).to receive(:enqueue_reindex)
      allow(WebhookUrls).to receive(:enqueue_events)

      patch "/templates/#{template.id}", params: { template: { name: 'Renamed' } }

      expect(SearchEntries).to have_received(:enqueue_reindex).with(template.reload)
    end
  end
end
