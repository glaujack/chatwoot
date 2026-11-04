json.payload do
  json.array! @scheduled_messages do |scheduled_message|
    json.partial! 'api/v1/models/scheduled_message', formats: [:json], scheduled_message: scheduled_message
  end
end
