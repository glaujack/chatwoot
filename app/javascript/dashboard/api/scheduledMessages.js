/* global axios */
import ApiClient from './ApiClient';

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('scheduled_messages', { accountScoped: true });
  }

  forConversation(conversationId) {
    return axios.get(this.url, { params: { conversation_id: conversationId } });
  }
}

export default new ScheduledMessagesAPI();
