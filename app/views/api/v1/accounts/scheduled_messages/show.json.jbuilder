json.payload do
  json.partial! 'api/v1/models/scheduled_message', formats: [:json], scheduled_message: @scheduled_message
end
