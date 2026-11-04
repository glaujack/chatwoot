class ScheduledMessages::DispatchJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ScheduledMessage.due.find_each { |scheduled| ScheduledMessages::SendService.new(scheduled).perform }
  end
end
