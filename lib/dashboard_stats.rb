# frozen_string_literal: true

module DashboardStats
  module_function

  MONTHS_RANGE = 6

  def call(submissions_scope)
    {
      monthly_completions: monthly_completions(submissions_scope),
      avg_completion_hours: avg_completion_hours(submissions_scope),
      adoption_by_direction: adoption_by_direction(submissions_scope),
      pending_reminders_count: pending_reminders_count(submissions_scope),
      pages_saved: pages_saved(submissions_scope)
    }
  end

  def completion_rows(scope)
    scope.joins(:submitters)
         .group(:id)
         .having(Submitter.arel_table[:completed_at].maximum.not_eq(nil))
         .pluck(:id, :created_at, Submitter.arel_table[:completed_at].maximum)
  end

  def monthly_completions(scope)
    months = (0...MONTHS_RANGE).map { |i| i.months.ago.beginning_of_month }.reverse

    counts = completion_rows(scope).each_with_object(Hash.new(0)) do |(_, _, completed_at), acc|
      acc[completed_at.beginning_of_month] += 1
    end

    months.map { |month| [month, counts[month] || 0] }
  end

  def avg_completion_hours(scope)
    rows = completion_rows(scope)

    return nil if rows.empty?

    total_hours = rows.sum { |_, created_at, completed_at| (completed_at - created_at) / 3600.0 }

    (total_hours / rows.size).round(1)
  end

  def adoption_by_direction(scope)
    total = scope.count

    return {} if total.zero?

    scope.joins(:created_by_user)
         .group('users.direction')
         .count
         .transform_keys { |direction| direction.presence || I18n.t('unspecified') }
         .transform_values { |count| { count:, percent: (count * 100.0 / total).round(1) } }
         .sort_by { |_, v| -v[:count] }
         .to_h
  end

  def pending_reminders_count(scope)
    reminded_submitter_ids = SubmissionEvent.where(event_type: 'send_reminder_email')
                                            .where(submission_id: scope.select(:id))
                                            .select(:submitter_id)

    Submitter.where(submission_id: scope.select(:id))
             .where(completed_at: nil, declined_at: nil)
             .where(id: reminded_submitter_ids)
             .distinct
             .count
  end

  def pages_saved(scope)
    scope.completed
         .preload(:submitters)
         .sum do |submission|
      pages = submission.schema_documents.sum { |doc| doc.metadata.dig('pdf', 'number_of_pages').to_i }

      pages * submission.submitters.size
    end
  end
end
