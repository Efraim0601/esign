# frozen_string_literal: true

describe 'TemplatesRecipientsController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }

  before { sign_in author }

  describe 'POST /templates/:template_id/recipients' do
    it 'normalizes submitter params and persists cleaned recipients' do
      post "/templates/#{template.id}/recipients", params: {
        template: {
          submitters: {
            '0' => {
              uuid: 'u-1',
              name: 'Requester',
              option: 'is_requester',
              order: '0',
              email: ''
            },
            '1' => {
              uuid: 'u-2',
              name: 'Linked',
              option: 'linked_to_u-1',
              order: '1'
            },
            '2' => {
              uuid: 'u-3',
              name: 'Invite by',
              option: 'invite_by_u-1',
              order: '2'
            },
            '3' => {
              uuid: 'u-4',
              name: 'Optional invite',
              option: 'optional_invite_by_u-2',
              order: '3'
            },
            '4' => {
              uuid: '',
              name: 'Ignored'
            }
          }
        }
      }

      expect(response).to have_http_status(:ok)
      submitters = template.reload.submitters
      expect(submitters.size).to eq(4)
      expect(submitters[0]).to include('uuid' => 'u-1', 'is_requester' => true)
      expect(submitters[1]).to include('uuid' => 'u-2', 'linked_to_uuid' => 'u-1')
      expect(submitters[2]).to include('uuid' => 'u-3', 'invite_by_uuid' => 'u-1')
      expect(submitters[3]).to include('uuid' => 'u-4', 'optional_invite_by_uuid' => 'u-2')
      expect(submitters.any? { |s| s.key?('order') }).to be(false)
      expect(submitters.any? { |s| s['name'] == 'Ignored' }).to be(false)
    end

    it 'clears requester/invite fields when option is not_set and keeps non sequential order' do
      post "/templates/#{template.id}/recipients", params: {
        template: {
          submitters: {
            '0' => {
              uuid: 'u-1',
              name: 'Unset',
              option: 'not_set',
              is_requester: '1',
              email: 'x@example.test',
              linked_to_uuid: 'u-9',
              invite_by_uuid: 'u-8',
              invite_via_field_uuid: 'f-1',
              optional_invite_by_uuid: 'u-7',
              order: '5'
            }
          }
        }
      }

      expect(response).to have_http_status(:ok)
      submitter = template.reload.submitters.first
      expect(submitter['uuid']).to eq('u-1')
      expect(submitter['order']).to eq(5)
      expect(submitter).not_to have_key('is_requester')
      expect(submitter).not_to have_key('email')
      expect(submitter).not_to have_key('linked_to_uuid')
      expect(submitter).not_to have_key('invite_by_uuid')
      expect(submitter).not_to have_key('invite_via_field_uuid')
      expect(submitter).not_to have_key('optional_invite_by_uuid')
    end
  end
end
