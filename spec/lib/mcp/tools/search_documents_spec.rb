# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mcp::Tools::SearchDocuments do
  describe '.call' do
    it 'applies default limit when invalid and serializes submissions' do
      scope = double('scope')
      current_user = double('user')
      current_ability = double('ability')
      submitter = double('submitter', email: 'a@example.test', name: 'Alice', phone: '+331', status: 'pending')
      template = double('template', name: 'T')
      submission = double('submission', id: 5, template: template, submitters: [submitter])

      accessible_scope = double('accessible_scope')
      allow(accessible_scope).to receive(:active).and_return(:active_scope)
      allow(Submission).to receive(:accessible_by).with(current_ability).and_return(accessible_scope)
      allow(Submissions).to receive(:search).with(current_user, :active_scope, 'alice', search_template: true).and_return(scope)
      allow(scope).to receive(:preload).with(:submitters, :template).and_return(scope)
      allow(scope).to receive(:order).with(id: :desc).and_return(scope)
      allow(scope).to receive(:limit).with(10).and_return([submission])
      allow(Submissions::SerializeForApi).to receive(:build_status).with(submission, [submitter]).and_return('pending')

      helpers = double('helpers')
      allow(helpers).to receive(:submission_url).with(5, **Docuseal.default_url_options).and_return('https://x/submissions/5')
      allow(Rails.application).to receive(:routes).and_return(double('routes', url_helpers: helpers))

      result = described_class.call({ 'q' => 'alice', 'limit' => 0 }, current_user, current_ability)

      parsed = JSON.parse(result[:content].first[:text])
      expect(parsed.first['id']).to eq(5)
      expect(parsed.first['documents_url']).to eq('https://x/submissions/5')
    end
  end
end
