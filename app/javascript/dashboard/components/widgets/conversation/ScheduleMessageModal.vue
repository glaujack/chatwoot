<script setup>
// Schedule a message for later, once or repeating (fork patch, see EVOLUTION.md). The server sends it at the hour, as the agent who scheduled it.
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import scheduledMessagesAPI from 'dashboard/api/scheduledMessages';

const props = defineProps({
  show: { type: Boolean, default: false },
  conversationId: { type: Number, required: true },
  message: { type: String, default: '' },
});
const emit = defineEmits(['close', 'update:show']);

const { locale } = useI18n();
const pt = computed(() => String(locale.value || '').toLowerCase().startsWith('pt'));
const tr = (ptText, enText) => (pt.value ? ptText : enText);

const RECURRENCES = [
  ['once', 'Uma vez', 'Once'],
  ['daily', 'Todo dia', 'Every day'],
  ['weekly', 'Toda semana', 'Every week'],
  ['monthly', 'Todo mês', 'Every month'],
];

const text = ref('');
const when = ref('');
const recurrence = ref('once');
const items = ref([]);
const busy = ref(false);

const pad = n => String(n).padStart(2, '0');
// The value a datetime-local input wants: local time, no zone, minutes only.
const toLocalInput = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;

const load = async () => {
  try {
    const { data } = await scheduledMessagesAPI.forConversation(props.conversationId);
    items.value = data.payload;
  } catch (e) {
    items.value = [];
  }
};

watch(
  () => props.show,
  shown => {
    if (!shown) return;
    text.value = props.message || '';
    const next = new Date(Date.now() + 60 * 60 * 1000);
    next.setMinutes(0, 0, 0);
    when.value = toLocalInput(next);
    recurrence.value = 'once';
    load();
  }
);

const canSave = computed(() => text.value.trim() && when.value && new Date(when.value) > new Date());

const save = async () => {
  busy.value = true;
  try {
    await scheduledMessagesAPI.create({
      conversation_id: props.conversationId,
      content: text.value.trim(),
      scheduled_at: new Date(when.value).toISOString(),
      recurrence: recurrence.value,
      time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    });
    useAlert(tr('Mensagem agendada', 'Message scheduled'));
    text.value = '';
    await load();
  } catch (e) {
    useAlert(e?.response?.data?.message || tr('Não consegui agendar', 'Could not schedule'));
  } finally {
    busy.value = false;
  }
};

const remove = async item => {
  try {
    await scheduledMessagesAPI.delete(item.id);
    items.value = items.value.filter(i => i.id !== item.id);
  } catch (e) {
    useAlert(tr('Não consegui cancelar', 'Could not cancel'));
  }
};

const label = item => RECURRENCES.find(r => r[0] === item.recurrence)?.[pt.value ? 1 : 2];
const format = ts => new Date(ts * 1000).toLocaleString(pt.value ? 'pt-BR' : undefined, { dateStyle: 'short', timeStyle: 'short' });
const close = () => emit('close');
</script>

<template>
  <Modal :show="show" @close="close" @update:show="emit('update:show', $event)">
    <div class="flex flex-col">
      <woot-modal-header :header-title="tr('Agendar mensagem', 'Schedule message')" />
      <div class="flex flex-col gap-4 px-6 pb-6 pt-2">
        <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
          {{ tr('Mensagem', 'Message') }}
          <textarea v-model="text" rows="4" class="w-full !mb-0" />
        </label>
        <div class="flex flex-wrap gap-4">
          <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
            {{ tr('Quando', 'When') }}
            <input v-model="when" type="datetime-local" class="!mb-0" />
          </label>
          <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
            {{ tr('Repetir', 'Repeat') }}
            <select v-model="recurrence" class="!mb-0">
              <option v-for="r in RECURRENCES" :key="r[0]" :value="r[0]">
                {{ pt ? r[1] : r[2] }}
              </option>
            </select>
          </label>
        </div>
        <div class="flex justify-end gap-2">
          <NextButton slate faded :label="tr('Fechar', 'Close')" @click="close" />
          <NextButton :label="tr('Agendar', 'Schedule')" :is-loading="busy" :disabled="!canSave" @click="save" />
        </div>

        <div v-if="items.length" class="flex flex-col gap-2 pt-2 border-t border-n-weak">
          <p class="text-sm font-medium text-n-slate-12">{{ tr('Agendadas nesta conversa', 'Scheduled in this conversation') }}</p>
          <div v-for="item in items" :key="item.id" class="flex items-start justify-between gap-3 p-3 rounded-lg bg-n-alpha-2">
            <div class="min-w-0">
              <p class="text-sm break-words text-n-slate-12">{{ item.content }}</p>
              <p class="text-xs text-n-slate-11">
                {{ format(item.scheduled_at) }} · {{ label(item) }}
                <span v-if="item.status === 'failed'" class="text-n-ruby-11"> · {{ tr('falhou', 'failed') }}: {{ item.last_error }}</span>
              </p>
            </div>
            <NextButton ruby faded sm :label="tr('Cancelar', 'Cancel')" @click="remove(item)" />
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>
