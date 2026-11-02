# Fork do Chatwoot com a opção "Evolution"

Este fork acrescenta **Caixa de entrada → WhatsApp → Evolution**: um assistente que cria a instância na Evolution API,
mostra o QR Code (com contagem regressiva e renovação automática), espera a conexão e cria a caixa de entrada pronta.

## O que muda em relação ao Chatwoot oficial (de propósito, o mínimo)
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/EvolutionWhatsapp.vue` — arquivo novo (o assistente).
- `.../channels/Whatsapp.vue` — 13 linhas: o card "Evolution" e a linha que renderiza o assistente.
- Nenhuma migração de banco, nenhuma rota Rails. A lógica da Evolution fica no serviço **ponte**, fora daqui.
- `.github/workflows/evo-*.yml` e `.evo/UPSTREAM` — compilação da imagem e vigia de versões.

## Como as atualizações funcionam (a produção nunca muda sozinha)
1. `evo-watch` roda todo dia, vê se saiu release nova do Chatwoot e tenta aplicar o patch numa branch `candidate/<versão>`.
2. Abre uma *issue* "Chatwoot X disponível" (o GitHub avisa por e-mail) dizendo se aplicou limpo ou deu conflito, e compila uma imagem candidata.
3. A produção usa **uma tag fixa** (`ghcr.io/<dono>/chatwoot:<versão>-<n>`), nunca `latest`. Só muda quando a troca é aprovada.
4. Troca = backup do banco + nova tag. Volta atrás = tag anterior (e o backup, se a versão nova tiver migrado o banco).

## Convenção de tags
`git tag evo-4.19.1-1 && git push origin evo-4.19.1-1` → imagem `4.19.1-1`.
