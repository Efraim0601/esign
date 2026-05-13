# frozen_string_literal: true

describe 'TemplatesPrefillableFieldsController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, author:) }
  let(:field_uuid) { template.fields.first['uuid'] }

  before { sign_in author }

  describe 'POST /templates/:template_id/prefillable_fields' do
    it 'enables prefillable and readonly flags' do
      post "/templates/#{template.id}/prefillable_fields", params: { field_uuid: field_uuid, prefillable: 'true' }

      expect(response).to have_http_status(:ok)
      updated = template.reload.fields.find { |f| f['uuid'] == field_uuid }
      expect(updated['prefillable']).to eq(true)
      expect(updated['readonly']).to eq(true)
    end

    it 'removes prefillable and readonly flags when disabled' do
      field = template.fields.find { |f| f['uuid'] == field_uuid }
      field['prefillable'] = true
      field['readonly'] = true
      template.update!(fields: template.fields)

      post "/templates/#{template.id}/prefillable_fields", params: { field_uuid: field_uuid, prefillable: 'false' }

      expect(response).to have_http_status(:ok)
      updated = template.reload.fields.find { |f| f['uuid'] == field_uuid }
      expect(updated.key?('prefillable')).to be(false)
      expect(updated.key?('readonly')).to be(false)
    end
  end
end
