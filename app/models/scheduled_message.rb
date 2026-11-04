# == Schema Information
#
# Table name: scheduled_messages
#
#  id              :bigint           not null, primary key
#  attempts        :integer          default(0), not null
#  content         :text             not null
#  last_error      :string
#  last_run_at     :datetime
#  next_run_at     :datetime         not null
#  recurrence      :integer          default("once"), not null
#  status          :integer          default("active"), not null
#  time_zone       :string           default("UTC"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
class ScheduledMessage < ApplicationRecord
  MAX_ATTEMPTS = 5
  # A repeating message that could not go out within this time of its hour is skipped, not sent late ("bom dia" at midnight).
  MAX_LATE = 30.minutes
  STEPS = { 'daily' => 1.day, 'weekly' => 1.week, 'monthly' => 1.month }.freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :user

  enum :recurrence, { once: 0, daily: 1, weekly: 2, monthly: 3 }, prefix: true
  enum :status, { active: 0, done: 1, failed: 2 }

  validates :content, presence: true, length: { maximum: 4000 }
  validates :time_zone, inclusion: { in: TZInfo::Timezone.all_identifiers }
  validate :run_in_the_future, if: -> { new_record? || next_run_at_changed? }

  scope :due, -> { active.where(next_run_at: ..Time.current) }

  def stale?
    !recurrence_once? && next_run_at < MAX_LATE.ago
  end

  # The run went out (or was skipped): a one-off is finished, a repeating one waits for its next turn on the same wall-clock hour.
  def advance!(error: nil)
    return update!(status: :done, last_run_at: Time.current, attempts: 0, last_error: error) if recurrence_once?

    update!(next_run_at: following_run_at, last_run_at: Time.current, attempts: 0, last_error: error)
  end

  def register_failure!(message)
    failed_for_good = attempts + 1 >= MAX_ATTEMPTS
    update!(attempts: attempts + 1, last_error: message.to_s.truncate(250), status: failed_for_good ? :failed : :active)
  end

  private

  def following_run_at
    step = STEPS.fetch(recurrence)
    following = next_run_at.in_time_zone(time_zone) + step
    following += step while following <= Time.current
    following
  end

  def run_in_the_future
    errors.add(:next_run_at, 'must be in the future') if next_run_at.present? && next_run_at <= Time.current
  end
end
