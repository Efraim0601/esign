# frozen_string_literal: true

module Submitters
  module MaybeUpdateDefaultValues
    module_function

    FULL_NAME_FIELDS  = ['full name', 'legal name', 'name', 'signer name',
                         'nom', 'nom complet', 'nom du signataire',
                         'nom et prénom', 'nom et prenom'].freeze
    FIRST_NAME_FIELDS = ['first name', 'prénom', 'prenom'].freeze
    LAST_NAME_FIELDS  = ['last name', 'nom de famille'].freeze

    def call(submitter, current_user)
      user =
        if current_user && current_user.email == submitter.email
          current_user
        else
          submitter.account.users.find_by(email: submitter.email)
        end

      fields = submitter.submission.template_fields || submitter.submission.template.fields

      fields.each do |field|
        next if field['submitter_uuid'] != submitter.uuid

        default_value = get_default_value_for_field(field, user, submitter)

        submitter.values[field['uuid']] ||= default_value if default_value.present?
      end

      submitter.save!
    end

    def get_default_value_for_field(field, user, submitter)
      field_name = field['name'].to_s.downcase

      if field_name.in?(FULL_NAME_FIELDS)
        user&.full_name.presence || submitter.name.presence
      elsif field_name.in?(FIRST_NAME_FIELDS)
        user&.first_name.presence || submitter.first_name.presence
      elsif field_name.in?(LAST_NAME_FIELDS)
        user&.last_name.presence || submitter.last_name.presence
      elsif field['type'] == 'initials' && user && (initials = UserConfigs.load_initials(user))
        attachment = ActiveStorage::Attachment.find_or_create_by!(
          blob_id: initials.blob_id,
          name: 'attachments',
          record: submitter
        )

        attachment.uuid
      end
    end
  end
end
