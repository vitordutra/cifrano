# O que eu discordo ou acho arriscado no SPEC

Conforme pedido na seção 15: retorno direto, sem diplomacia. Isso não são bloqueios — são pontos técnicos que eu recomendo revisar antes ou durante a fase em que aparecem. Se você discordar de mim, seguimos com sua decisão; é só para você decidir de olhos abertos.

**Todos os itens abaixo foram decididos, todos a favor da minha recomendação.** `SPEC.md` e `schema-proposto.sql` já refletem as decisões.

---

## 1. Detecção de pagamento de fatura por padrão de texto na descrição é o critério mais fraco dos três (seção 5.2)

A seção 5.2 lista três sinais para detectar pagamento de fatura: conta destino `CREDIT_CARD`, valor igual ao total da fatura fechada, e descrição contendo padrão de pagamento. O terceiro é o problema — descritor de pagamento de fatura varia por banco, muda sem aviso, e "conter padrão" é exatamente o tipo de heurística frágil que a seção 8 evita deliberadamente ao preferir *score* a regra binária.

Com a tabela `statement`, o segundo critério (valor bate com o total fechado) já é suficiente sozinho, combinado com o primeiro (conta destino é `CREDIT_CARD` do tipo esperado).

**Decisão: descartar o padrão de texto como critério de detecção.** Ele vira só reforço de exibição na UI ("por que marcamos isso como pagamento de fatura"), nunca parte da lógica. `SPEC.md` seção 5.2 atualizado.

## 2. A raspagem de HTML da SEFAZ (seção 7.1) é a dependência mais frágil do sistema, e é a feature principal

Você chamou notas fiscais de "a feature principal" (seção 7). O caminho primário dela depende de fazer parse de HTML de um portal governamental estadual que você não controla, sem contrato de API, sem SLA, sujeito a CAPTCHA, mudança de layout ou bloqueio por taxa de acesso sem aviso — e isso multiplicado por UF (você já vai ter dois parsers, MA e SP, cada um podendo quebrar independente do outro).

**Decisão: cache permanente do resultado parseado por chave de acesso.** A própria tabela `receipt` já cumpre esse papel — a regra de aplicação é sempre checar `receipt` por `access_key` antes de chamar qualquer `NfceProvider`, nunca re-consultar o portal para uma nota já persistida. Documentado em `schema-proposto.sql` junto da tabela `receipt`.

## 3. Custo de chamada a LLM não tinha controle nenhum no SPEC (seção 11.7 só cobria privacidade)

Três pontos diferentes do sistema chamam API de modelo de linguagem: categorização de último recurso (seção 9), extração por visão (seção 7.2), e o assistente financeiro inteiro (seção 11). A seção 11.7 fala só de privacidade — "quais dados são enviados" — e nada sobre quanto isso custa por mês nem sobre o que acontece se um bug gerar uma chamada em loop.

**Decisão: `llm_call_log` + limite mensal configurável, com degradação graciosa.** Tabela `llm_call_log` (propósito, provedor, modelo, tokens, custo estimado) registrada em `schema-proposto.sql`, seção G.1. O limite em si é regra de aplicação sobre a soma do mês corrente, não uma tabela nova. Se estourado: categorização cai para "sem sugestão" em vez de erro, extração de imagem para de processar e avisa — implementação entra nas fases 3/4/6, quando cada chamador existir.

## 4. A regra de auto-vínculo da conciliação não definia o caso de candidato único (seção 8)

"score ≥ 0.85 **e** o segundo melhor candidato < 0.60 → vincula automaticamente." Isso pressupõe que sempre existe um segundo candidato para comparar. Quando há **só um** candidato com score ≥ 0.85, a regra como está escrita ficava ambígua.

**Decisão: ausência de segundo candidato conta como score 0.** Candidato único com score ≥ 0.85 vincula automaticamente, sem passar pela fila `receipt_reconciliation_candidate`. É a leitura mais natural e evita que o caso mais comum do sistema (comprei em um lugar, num dia, com um valor exato, sem ambiguidade nenhuma) caia sem necessidade na revisão manual. Documentado junto de `receipt_transaction_link` em `schema-proposto.sql`.

## 5. `record` para entidade JPA não funciona, e a seção 2 do SPEC podia ser lida como se funcionasse

A seção 2 diz "Sem Lombok — use records e classes normais", sem distinguir onde cada um se aplica. **Entidade JPA nunca é `record`**: Hibernate precisa de um construtor sem argumentos e de conseguir alterar os campos por reflection para *dirty checking* — um `record` é imutável por definição e não tem construtor vazio.

**Decisão confirmada: `record` para value objects de domínio e DTOs (`Money`, requests/responses, o payload do snapshot); classes normais e mutáveis só em `adapter/out`, para as entidades `@Entity`.** É exatamente a separação que a arquitetura hexagonal da seção 3 já impõe — só ficou escrito para não virar suposição implícita no meio do código, quando a Fase 1 começar a escrever entidades.
