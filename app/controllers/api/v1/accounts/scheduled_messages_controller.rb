class Api::V1::Accounts::ScheduledMessagesController < Api::V1::Accounts::BaseController
  before_action :fetch_scheduled_message, only: [:update, :destroy]

  def index
    @scheduled_messages = own_messages.where.not(status: :done).includes(conversation: :contact).order(:next_run_at)
    @scheduled_messages = @scheduled_messages.where(conversation: conversation) if params[:conversation_id].present?
  end

  def create
    authorize conversation, :show?
    @scheduled_message = own_messages.create!(permitted_params.to_h.merge(conversation: conversation, user: Current.user, next_run_at: params[:scheduled_at]))
    render :show
  end

  def update
    attributes = permitted_params.to_h
    attributes = attributes.merge(next_run_at: params[:scheduled_at], status: :active, attempts: 0, last_error: nil) if params[:scheduled_at].present?
    @scheduled_message.update!(attributes)
    render :show
  end

  def destroy
    @scheduled_message.destroy!
    head :ok
  end

  private

  def own_messages
    Current.account.scheduled_messages.where(user: Current.user)
  end

  def fetch_scheduled_message
    @scheduled_message = own_messages.find(params[:id])
  end

  def conversation
    @conversation ||= Current.account.conversations.find_by!(display_id: params[:conversation_id])
  end

  def permitted_params
    params.permit(:content, :recurrence, :time_zone)
  end
end
