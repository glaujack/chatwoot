<script setup>
/* global axios */
// WhatsApp through an Evolution API server (fork patch, see EVOLUTION.md).
// Steps: name -> QR code with a countdown that renews itself -> connected -> the inbox is created and the
// native "add agents" step follows. Everything about Evolution lives in the separate "bridge" service
// (same host, /evolution/api/*); this component only talks to it with the dashboard's own login headers.
import { computed, onBeforeUnmount, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import router from '../../../../index';
import NextButton from 'dashboard/components-next/button/Button.vue';

const BRIDGE = '/evolution/api';
const POLL_MS = 2000;

const store = useStore();
const { locale } = useI18n();
const pt = computed(() => String(locale.value || '').toLowerCase().startsWith('pt'));
const tr = (ptText, enText) => (pt.value ? ptText : enText);

const step = ref('name'); // name | qr | done
const inboxName = ref('');
const busy = ref(false);
const instance = ref('');
const webhookUrl = ref('');
const qr = ref('');
const secondsLeft = ref(0);
const renewing = ref(false);
const phone = ref('');
const error = ref('');

let tick = null;
let poll = null;
let finishing = false;

const stopTimers = () => {
  clearInterval(tick);
  clearInterval(poll);
  tick = null;
  poll = null;
};
onBeforeUnmount(stopTimers);

const message = e =>
  e?.response?.data?.detail ||
  e?.message ||
  tr('Algo deu errado. Tente de novo.', 'Something went wrong. Try again.');

const showQr = data => {
  qr.value = data.qr || '';
  secondsLeft.value = data.expires_in || 45;
};

const renew = async () => {
  if (renewing.value || !instance.value) return;
  renewing.value = true;
  try {
    const { data } = await axios.post(`${BRIDGE}/instances/${instance.value}/qr`);
    showQr(data);
  } catch (e) {
    error.value = message(e);
  } finally {
    renewing.value = false;
  }
};

const finish = async () => {
  if (finishing) return;
  finishing = true;
  stopTimers();
  try {
    const channel = await store.dispatch('inboxes/createChannel', {
      name: inboxName.value.trim(),
      channel: { type: 'api', webhook_url: webhookUrl.value },
    });
    await axios.post(`${BRIDGE}/instances/${instance.value}/link`, {
      inbox_id: channel.id,
    });
    step.value = 'done';
    setTimeout(() => {
      router.replace({
        name: 'settings_inboxes_add_agents',
        params: { page: 'new', inbox_id: channel.id },
      });
    }, 1800);
  } catch (e) {
    finishing = false;
    error.value = message(e);
    useAlert(error.value);
  }
};

const checkStatus = async () => {
  try {
    const { data } = await axios.get(`${BRIDGE}/instances/${instance.value}/status`);
    if (data.state === 'open') {
      phone.value = data.phone || '';
      await finish();
    }
  } catch (e) {
    // a failed poll is retried on the next tick
  }
};

const start = async () => {
  const name = inboxName.value.trim();
  if (!name) return;
  error.value = '';
  busy.value = true;
  try {
    const { data } = await axios.post(`${BRIDGE}/instances`, { name });
    instance.value = data.instance;
    webhookUrl.value = data.webhook_url;
    showQr(data);
    step.value = 'qr';
    tick = setInterval(() => {
      if (secondsLeft.value > 0) secondsLeft.value -= 1;
      if (secondsLeft.value <= 0) renew();
    }, 1000);
    poll = setInterval(checkStatus, POLL_MS);
  } catch (e) {
    error.value = message(e);
  } finally {
    busy.value = false;
  }
};

const cancel = async () => {
  stopTimers();
  const gone = instance.value;
  instance.value = '';
  if (gone) {
    try {
      await axios.delete(`${BRIDGE}/instances/${gone}`);
    } catch (e) {
      // the bridge cleans up unlinked instances by itself
    }
  }
  qr.value = '';
  step.value = 'name';
};

const progress = computed(() => Math.max(0, Math.min(1, secondsLeft.value / 45)));
</script>

<template>
  <div class="max-w-xl">
    <template v-if="step === 'name'">
      <h2 class="mb-1 text-lg font-medium text-n-slate-12">
        {{ tr('Conectar WhatsApp (Evolution)', 'Connect WhatsApp (Evolution)') }}
      </h2>
      <p class="mb-5 text-sm text-n-slate-11">
        {{
          tr(
            'Dê um nome à caixa de entrada e leia o QR Code com o WhatsApp do número que vai atender.',
            'Name the inbox, then scan the QR code with the WhatsApp of the number that will answer.'
          )
        }}
      </p>
      <label class="block mb-1 text-sm font-medium text-n-slate-12">
        {{ tr('Nome da caixa de entrada', 'Inbox name') }}
      </label>
      <input
        v-model="inboxName"
        type="text"
        class="w-full mb-4"
        :placeholder="tr('Ex.: Atendimento', 'E.g. Support')"
        @keyup.enter="start"
      />
      <p v-if="error" class="mb-3 text-sm text-n-ruby-11">{{ error }}</p>
      <NextButton
        :is-loading="busy"
        :disabled="!inboxName.trim()"
        :label="tr('Gerar QR Code', 'Generate QR code')"
        @click="start"
      />
    </template>

    <template v-else-if="step === 'qr'">
      <h2 class="mb-1 text-lg font-medium text-n-slate-12">
        {{ tr('Leia o QR Code', 'Scan the QR code') }}
      </h2>
      <ol class="mb-5 text-sm list-decimal ps-5 text-n-slate-11 space-y-1">
        <li>{{ tr('Abra o WhatsApp no celular.', 'Open WhatsApp on your phone.') }}</li>
        <li>
          {{
            tr(
              'Toque em Configurações → Dispositivos conectados.',
              'Tap Settings → Linked devices.'
            )
          }}
        </li>
        <li>{{ tr('Toque em Conectar um dispositivo.', 'Tap Link a device.') }}</li>
        <li>{{ tr('Aponte a câmera para o código abaixo.', 'Point the camera at the code below.') }}</li>
      </ol>

      <div class="flex items-center gap-6">
        <div
          class="p-3 bg-white border rounded-xl border-n-weak size-64 flex items-center justify-center"
        >
          <img v-if="qr && !renewing" :src="qr" alt="QR" class="size-full" />
          <span v-else class="text-sm text-slate-500">
            {{ tr('Gerando novo código…', 'Generating a new code…') }}
          </span>
        </div>
        <div class="flex flex-col items-center gap-2">
          <div class="relative size-20">
            <svg viewBox="0 0 36 36" class="size-20 -rotate-90">
              <circle cx="18" cy="18" r="16" fill="none" stroke-width="3" class="stroke-n-weak" />
              <circle
                cx="18"
                cy="18"
                r="16"
                fill="none"
                stroke-width="3"
                stroke-linecap="round"
                class="stroke-n-brand"
                :stroke-dasharray="100.5"
                :stroke-dashoffset="100.5 * (1 - progress)"
              />
            </svg>
            <span
              class="absolute inset-0 flex items-center justify-center text-xl font-medium text-n-slate-12"
            >
              {{ secondsLeft }}
            </span>
          </div>
          <span class="text-xs text-center text-n-slate-11">
            {{ tr('O código se renova sozinho', 'The code renews itself') }}
          </span>
        </div>
      </div>

      <p v-if="error" class="mt-4 text-sm text-n-ruby-11">{{ error }}</p>
      <div class="mt-5 flex gap-3">
        <NextButton
          faded
          slate
          :label="tr('Novo código agora', 'New code now')"
          :is-loading="renewing"
          @click="renew"
        />
        <NextButton
          link
          slate
          :label="tr('Cancelar', 'Cancel')"
          @click="cancel"
        />
      </div>
    </template>

    <template v-else>
      <div class="flex flex-col items-center py-10 text-center">
        <span class="mb-3 text-4xl">✅</span>
        <h2 class="mb-1 text-lg font-medium text-n-slate-12">
          {{ tr('WhatsApp conectado!', 'WhatsApp connected!') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          <span v-if="phone">{{ phone }} · </span>
          {{ tr('Preparando a caixa de entrada…', 'Setting up the inbox…') }}
        </p>
      </div>
    </template>
  </div>
</template>
