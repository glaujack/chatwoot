class ScheduledMessages::SendService
  def initialize(scheduled_message)
    @scheduled = scheduled_message
  end

  def perform
    @scheduled.with_lock do
      next unless @scheduled.active? && @scheduled.next_run_at <= Time.current

      @scheduled.stale? ? @scheduled.advance!(error: 'Horário perdido, envio pulado') : deliver
    end
  end

  private

  def deliver
    Messages::MessageBuilder.new(@scheduled.user, @scheduled.conversation, content: @scheduled.content, message_type: 'outgoing').perform
    @scheduled.advance!
  rescue StandardError => e
    @scheduled.register_failure!(e.message)
  end
end
