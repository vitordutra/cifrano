-- =============================================================================
-- Cifrano — proposta de schema completo, para revisão (docs/schema-proposto.sql)
-- =============================================================================
-- Este arquivo NÃO é uma migration. É o modelo de dados do sistema inteiro,
-- para você revisar de uma vez antes que qualquer parte dele vire Flyway V*.
--
-- Convenção de nomes (docs/SPEC.md, seção 0 / CLAUDE.md): identificadores em
-- inglês, sempre. Os comentários deste arquivo são em português porque este
-- é um documento de estudo, não código — mas toda tabela, coluna, constraint
-- e índice abaixo já está no nome definitivo que vai para o banco.
--
-- Money (docs/SPEC.md, seção 4.1): toda coluna monetária é NUMERIC(15,2).
-- Nunca double/float. Moeda não é persistida por linha (ver questions.md,
-- item 2) — o sistema é BRL-only e isso é constante da aplicação.
--
-- Tempo (seção 4.2): toda coluna de instante é TIMESTAMPTZ, guardada em UTC.
-- A conversão para America/Sao_Paulo acontece só na borda (apresentação).
--
-- Cada tabela abaixo vem com: o fato do mundo real que ela representa, as
-- colunas com o motivo do tipo escolhido, e as constraints/índices com o
-- motivo de cada um.
--
-- Nota de ordenação: as tabelas estão agrupadas por assunto/fase, não pela
-- ordem de criação que uma migration exigiria — `bank_transaction`
-- referencia `category`, que só aparece na Seção C. Numa migration real a
-- ordem de `CREATE TABLE` respeita as FKs; aqui a ordem prioriza leitura.
-- =============================================================================


-- =============================================================================
-- SEÇÃO A — Contas e instituições (Fase 0/1)
-- =============================================================================

-- institution: a "empresa" por trás de uma ou mais contas — Mercado Pago,
-- Banco do Brasil, Nubank, Swile. Existe como tabela própria (e não como
-- string solta em `account`) porque o sync da Pluggy é por instituição
-- (um `itemId` cobre todas as contas daquela conexão) e porque duas contas
-- do mesmo Nubank (cartão + NuConta) precisam saber que são "parentes" —
-- é essa relação que o InternalTransferDetector usa para não confundir
-- "conta diferente" com "instituição diferente" (SPEC seção 5.1).
CREATE TABLE institution (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(120) NOT NULL,
    -- Identificador do provedor de agregação (Pluggy "connector id" ou
    -- equivalente). Nulo para instituições sem conector (fallback manual).
    provider_code   VARCHAR(60),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- account: uma conta bancária, cartão de crédito, ou saldo de benefício.
-- O tipo (`type`) e o tipo de fundo (`fund_type`) são as duas dimensões
-- que o resto do sistema consulta o tempo todo:
--   - `type` diz COMO a conta se comporta (cartão fecha fatura, corrente não)
--   - `fund_type` diz SE o saldo é fungível (SPEC seção 4.4) — GENERAL soma
--     no consolidado, RESTRICTED nunca soma e nunca origina transferência
CREATE TYPE account_type AS ENUM ('CHECKING', 'SAVINGS', 'CREDIT_CARD', 'BENEFIT');
CREATE TYPE fund_type AS ENUM ('GENERAL', 'RESTRICTED');

CREATE TABLE account (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id  UUID NOT NULL REFERENCES institution(id),
    name            VARCHAR(120) NOT NULL,
    type            account_type NOT NULL,
    fund_type       fund_type NOT NULL DEFAULT 'GENERAL',
    -- Identificador da conta no provedor de agregação. Único porque é a
    -- chave que o sync usa para saber "essa conta já existe?" no upsert.
    provider_account_id VARCHAR(120),
    -- Saldo é sempre recalculável a partir das transações, mas guardamos
    -- o último saldo informado pelo provedor como cache de leitura rápida
    -- do dashboard — nunca a fonte da verdade.
    last_known_balance NUMERIC(15,2),
    last_synced_at  TIMESTAMPTZ,
    active          BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_account_provider_account_id UNIQUE (provider_account_id)
);

CREATE INDEX ix_account_institution ON account(institution_id);

-- statement: a fatura de um cartão de crédito — o agrupamento das compras
-- entre um fechamento e o próximo. Existe como tabela própria (e não como
-- cálculo ad-hoc) porque a seção 5.2 do SPEC detecta pagamento de fatura
-- comparando o valor pago contra "o total da fatura fechada", e sem uma
-- linha que registre esse total no momento do fechamento, a comparação
-- fica refém de recalcular a soma toda vez — o que quebra se uma
-- transação for editada ou recategorizada depois.
CREATE TYPE statement_status AS ENUM ('OPEN', 'CLOSED', 'PAID', 'OVERDUE');

CREATE TABLE statement (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      UUID NOT NULL REFERENCES account(id),
    closing_date    DATE NOT NULL,
    due_date        DATE NOT NULL,
    -- Snapshot do total no momento do fechamento — não é "select sum(...)"
    -- ao vivo, é o valor que vira a referência para a detecção de pagamento.
    total_amount    NUMERIC(15,2),
    status          statement_status NOT NULL DEFAULT 'OPEN',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_statement_account_closing_date UNIQUE (account_id, closing_date)
);

CREATE INDEX ix_statement_account ON statement(account_id);


-- =============================================================================
-- SEÇÃO B — Transações (Fase 0/1/2)
-- =============================================================================

-- bank_transaction: um lançamento bancário. Chamamos de `bank_transaction`,
-- não `transaction`, para nunca colidir visualmente com a palavra reservada
-- SQL `TRANSACTION` em clientes, ORMs e no autocomplete do dia a dia
-- (questions.md, item 9) — mesmo o Postgres aceitando `transaction` como
-- identificador sem aspas.
CREATE TYPE transaction_source AS ENUM ('PLUGGY', 'FILE', 'SCREENSHOT', 'MANUAL');

CREATE TABLE bank_transaction (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id              UUID NOT NULL REFERENCES account(id),
    category_id             UUID REFERENCES category(id),

    -- Convenção de sinal (SPEC 4.1): despesa negativa, receita positiva.
    amount                  NUMERIC(15,2) NOT NULL,
    description             VARCHAR(300) NOT NULL,

    -- transactionDate: quando o banco contabilizou. purchaseDate: quando a
    -- compra aconteceu de fato. Em cartão de crédito elas divergem, e a
    -- conciliação com nota fiscal (seção 8) precisa da segunda. purchaseDate
    -- é nulável — nem todo tipo de lançamento tem as duas datas (PIX, TED,
    -- débito automático costumam ter só uma) — ver questions.md, item 3.
    transaction_date        TIMESTAMPTZ NOT NULL,
    purchase_date           TIMESTAMPTZ,

    -- Idempotência (SPEC 4.3): a chave que o upsert usa. externalId é o id
    -- do provedor; sozinho ele não basta porque dois provedores diferentes
    -- podem, em teoria, reaproveitar o mesmo id — por isso o par com a conta.
    external_id             VARCHAR(120),
    provider_account_id     VARCHAR(120),

    -- Parcelamento (seção 5.3): purchase_group_id agrupa todas as parcelas
    -- da mesma compra, para as duas visões (caixa vs. competência).
    installment_number      INTEGER,
    total_installments      INTEGER,
    purchase_group_id       UUID,

    -- Transferência interna e pagamento de fatura (seções 5.1/5.2) marcam
    -- aqui — a transação continua existindo e visível, só sai dos totais.
    excluded_from_reports   BOOLEAN NOT NULL DEFAULT false,

    source                  transaction_source NOT NULL,
    -- Deduplicação cruzada (seção 6.1): quando uma transação SCREENSHOT ou
    -- FILE é substituída por uma que chegou da Pluggy, a perdedora não é
    -- apagada — fica marcada, para auditoria, apontando para a vencedora.
    superseded_by_id        UUID REFERENCES bank_transaction(id),

    statement_id            UUID REFERENCES statement(id),

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_bank_transaction_external_id
        UNIQUE (external_id, provider_account_id),
    CONSTRAINT ck_bank_transaction_installments
        CHECK (
            (installment_number IS NULL AND total_installments IS NULL)
            OR (installment_number BETWEEN 1 AND total_installments)
        )
);

CREATE INDEX ix_bank_transaction_account ON bank_transaction(account_id);
CREATE INDEX ix_bank_transaction_category ON bank_transaction(category_id);
CREATE INDEX ix_bank_transaction_purchase_group ON bank_transaction(purchase_group_id);
-- Suporta o dashboard e os relatórios, que sempre filtram por período.
CREATE INDEX ix_bank_transaction_transaction_date ON bank_transaction(transaction_date);

-- internal_transfer: o vínculo entre duas bank_transaction que são, na
-- verdade, o mesmo movimento de dinheiro visto de dois lados (seção 5.1).
-- Modelada como entidade própria (e não como uma FK direta em
-- bank_transaction) porque a ligação é 1:1 mas simétrica — nenhum dos dois
-- lados "pertence" ao outro — e porque guardar aqui o motivo da detecção
-- (automática vs. confirmada por você) documenta a decisão sem sujar a
-- tabela de transações com colunas que só fazem sentido nesse caso raro.
CREATE TABLE internal_transfer (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outgoing_transaction_id UUID NOT NULL REFERENCES bank_transaction(id),
    incoming_transaction_id UUID NOT NULL REFERENCES bank_transaction(id),
    detected_automatically  BOOLEAN NOT NULL,
    confirmed_by_user       BOOLEAN NOT NULL DEFAULT false,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_internal_transfer_pair
        UNIQUE (outgoing_transaction_id, incoming_transaction_id)
);


-- =============================================================================
-- SEÇÃO C — Categorização (Fase 3)
-- =============================================================================

-- category: hierarquia de dois níveis (SPEC seção 9). Auto-relacionamento
-- em vez de duas tabelas (questions.md, item 5) — uma categoria só, com
-- parent_id opcional, permite consultar "todas as categorias e
-- subcategorias" com uma query sem UNION.
--
-- `code` é o identificador estável em inglês (usado por regra de
-- categorização e por relatório); `name` é o rótulo em português que
-- aparece na tela e que você pode editar sem quebrar nada que dependa
-- da categoria. É a mesma separação que o glossário faz entre termo de
-- domínio e identificador de código, aplicada a dado, não a schema.
CREATE TABLE category (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id       UUID REFERENCES category(id),
    code            VARCHAR(60) NOT NULL,
    name            VARCHAR(80) NOT NULL,
    color           VARCHAR(7),
    icon            VARCHAR(60),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_category_code UNIQUE (code)
);

-- Trigger de profundidade fica para a migration real (checar parent_id do
-- pai é NULL exige consultar outra linha, o que CHECK simples não faz).
-- Documentado aqui como decisão de schema: profundidade máxima 2.

CREATE INDEX ix_category_parent ON category(parent_id);

-- categorization_rule: as regras da seção 9, camadas "usuário" e "seed".
-- Uma tabela só para as duas, distinguidas por `is_user_defined` — a
-- precedência entre elas é lógica de aplicação (usuário vence seed), não
-- uma diferença estrutural que justifique tabelas separadas.
CREATE TYPE rule_match_type AS ENUM ('DESCRIPTION_CONTAINS', 'MERCHANT_CNPJ', 'AMOUNT_RANGE', 'ACCOUNT');

CREATE TABLE categorization_rule (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id         UUID NOT NULL REFERENCES category(id),
    match_type          rule_match_type NOT NULL,
    match_value         VARCHAR(300) NOT NULL,
    is_user_defined      BOOLEAN NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_categorization_rule_category ON categorization_rule(category_id);

-- Cache de sugestão de LLM (seção 9): "não chame a API duas vezes pro
-- mesmo merchant". A chave é o descritor normalizado — a mesma
-- normalização usada na conciliação da seção 8.
CREATE TABLE llm_categorization_cache (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    normalized_descriptor   VARCHAR(300) NOT NULL,
    suggested_category_id   UUID NOT NULL REFERENCES category(id),
    confidence              NUMERIC(4,3) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_llm_categorization_cache_descriptor UNIQUE (normalized_descriptor)
);


-- =============================================================================
-- SEÇÃO D — Notas fiscais e conciliação (Fase 4)
-- =============================================================================

CREATE TYPE receipt_source AS ENUM ('NFCE_QR', 'VISION_EXTRACTION', 'MANUAL');
CREATE TYPE receipt_status AS ENUM ('CONFIRMED', 'PENDING_MANUAL', 'NEEDS_REVIEW');

-- receipt: uma nota fiscal ou comprovante, vinda de QR de NFC-e (seção 7.1)
-- ou de extração por visão (seção 7.2). `access_key` só existe quando o
-- caminho é NFC-e; os outros campos existem sempre.
CREATE TABLE receipt (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source              receipt_source NOT NULL,
    status              receipt_status NOT NULL DEFAULT 'CONFIRMED',
    -- Chave de acesso de 44 dígitos da NFC-e. Nunca aparece em log
    -- (CLAUDE.md — "nunca logue... chave de acesso de NFC-e").
    access_key          CHAR(44),
    merchant_name        VARCHAR(200) NOT NULL,
    merchant_cnpj        VARCHAR(14),
    purchase_date        TIMESTAMPTZ NOT NULL,
    total_amount         NUMERIC(15,2) NOT NULL,
    payment_method       VARCHAR(60),
    -- Caminho da imagem original no filesystem, para auditoria (seção 7.2).
    image_path           VARCHAR(500),
    -- Diferença entre soma dos itens e o total, sinalizada na UI (seção 7.2).
    needs_review          BOOLEAN NOT NULL DEFAULT false,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_receipt_access_key UNIQUE (access_key)
);

CREATE INDEX ix_receipt_purchase_date ON receipt(purchase_date);
CREATE INDEX ix_receipt_merchant_cnpj ON receipt(merchant_cnpj);

-- receipt_item: cada linha da nota, com categoria própria — independente
-- da categoria da transação bancária vinculada (questions.md, item 6).
CREATE TABLE receipt_item (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id          UUID NOT NULL REFERENCES receipt(id),
    category_id         UUID REFERENCES category(id),
    description         VARCHAR(300) NOT NULL,
    quantity             NUMERIC(12,3) NOT NULL,
    unit_price           NUMERIC(15,2) NOT NULL,
    total_price          NUMERIC(15,2) NOT NULL
);

CREATE INDEX ix_receipt_item_receipt ON receipt_item(receipt_id);
CREATE INDEX ix_receipt_item_category ON receipt_item(category_id);

-- receipt_transaction_link: o vínculo N:N entre nota e transação (seção 8)
-- — uma nota pode ser paga com dois cartões, uma transação pode cobrir
-- duas notas. `confidence` guarda o score do ReconciliationService no
-- momento do vínculo, mesmo que o vínculo tenha sido confirmado depois.
CREATE TABLE receipt_transaction_link (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id              UUID NOT NULL REFERENCES receipt(id),
    transaction_id          UUID NOT NULL REFERENCES bank_transaction(id),
    confidence               NUMERIC(4,3) NOT NULL,
    matched_automatically    BOOLEAN NOT NULL,
    confirmed_by_user        BOOLEAN NOT NULL DEFAULT false,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_receipt_transaction_link UNIQUE (receipt_id, transaction_id)
);

-- merchant_alias: o aprendizado da seção 8 — depois que você confirma ou
-- corrige um vínculo, o par CNPJ → descritor de transação vira alias de
-- score 1.0 nas próximas comparações de estabelecimento.
CREATE TABLE merchant_alias (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_cnpj                VARCHAR(14) NOT NULL,
    normalized_transaction_descriptor VARCHAR(300) NOT NULL,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_merchant_alias UNIQUE (merchant_cnpj, normalized_transaction_descriptor)
);


-- =============================================================================
-- SEÇÃO E — Filas de revisão manual (questions.md, item 7)
-- =============================================================================
-- Três tabelas específicas em vez de uma genérica: cada uma tem FK real
-- para o que está comparando, então "listar pendências" é um JOIN comum,
-- não um payload JSON para interpretar antes de saber o que é.

CREATE TYPE review_status AS ENUM ('PENDING', 'CONFIRMED', 'REJECTED');

-- Candidatos ambíguos de transferência interna (seção 5.1: "múltiplos
-- candidatos... vão pra fila de revisão manual, não adivinhe").
CREATE TABLE internal_transfer_candidate (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outgoing_transaction_id UUID NOT NULL REFERENCES bank_transaction(id),
    incoming_transaction_id UUID NOT NULL REFERENCES bank_transaction(id),
    status                  review_status NOT NULL DEFAULT 'PENDING',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Candidatos ambíguos de deduplicação cruzada (seção 6.1: uma transação
-- manual/print que pode ser a mesma que uma vinda da Pluggy).
CREATE TABLE manual_entry_duplicate_candidate (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    manual_transaction_id        UUID NOT NULL REFERENCES bank_transaction(id),
    provider_transaction_id      UUID NOT NULL REFERENCES bank_transaction(id),
    score                        NUMERIC(4,3) NOT NULL,
    status                       review_status NOT NULL DEFAULT 'PENDING',
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Candidatos de conciliação nota↔transação com score entre 0.60 e 0.85,
-- ou empate técnico (seção 8).
CREATE TABLE receipt_reconciliation_candidate (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id           UUID NOT NULL REFERENCES receipt(id),
    transaction_id        UUID NOT NULL REFERENCES bank_transaction(id),
    score                 NUMERIC(4,3) NOT NULL,
    status                review_status NOT NULL DEFAULT 'PENDING',
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- SEÇÃO F — Orçamentos (Fase 5)
-- =============================================================================

CREATE TABLE budget (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id                  UUID NOT NULL REFERENCES category(id),
    -- Mês de referência como primeiro dia do mês, para orçamento mês a mês.
    reference_month               DATE NOT NULL,
    planned_amount                NUMERIC(15,2) NOT NULL,
    created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_budget_category_month UNIQUE (category_id, reference_month)
);


-- =============================================================================
-- SEÇÃO G — Perfil financeiro e assistente (Fase 6)
-- =============================================================================

-- financial_profile: singleton — só existe uma linha, porque o sistema é
-- single-user. Ainda assim é tabela (não colunas soltas em configuração)
-- porque tem campos versionáveis e o histórico de edição importa.
CREATE TABLE financial_profile (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    free_text_notes      TEXT,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- income_source: cada fonte de renda com os dois eixos da seção 11.2/4.4 —
-- grau de garantia (guaranteed) e grau de liberdade (fund_type, reaproveita
-- o mesmo enum de account: uma "renda" em vale-alimentação é RESTRICTED).
CREATE TYPE income_recurrence AS ENUM ('FIXED_MONTHLY', 'VARIABLE', 'IRREGULAR');

CREATE TABLE income_source (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    financial_profile_id     UUID NOT NULL REFERENCES financial_profile(id),
    name                     VARCHAR(120) NOT NULL,
    recurrence                income_recurrence NOT NULL,
    is_guaranteed             BOOLEAN NOT NULL,
    fund_type                 fund_type NOT NULL DEFAULT 'GENERAL',
    typical_amount             NUMERIC(15,2),
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_income_source_profile ON income_source(financial_profile_id);

CREATE TABLE fixed_commitment (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    financial_profile_id     UUID NOT NULL REFERENCES financial_profile(id),
    description               VARCHAR(200) NOT NULL,
    expected_amount            NUMERIC(15,2) NOT NULL,
    starts_on                  DATE,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE financial_goal (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    financial_profile_id     UUID NOT NULL REFERENCES financial_profile(id),
    description               VARCHAR(200) NOT NULL,
    target_amount              NUMERIC(15,2) NOT NULL,
    target_date                DATE,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- advice_snapshot: o objeto versionado da seção 11.3. O payload é JSONB
-- porque o formato do snapshot evolui por versão (seção 11.3: "versione o
-- formato... guarde cada um gerado") e não vale a pena migrar schema
-- relacional toda vez que um agregado novo entra na análise — mas
-- `schema_version` é coluna própria, não escondida dentro do JSON, porque
-- é ela que decide como ler o payload.
CREATE TABLE advice_snapshot (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schema_version        INTEGER NOT NULL,
    payload               JSONB NOT NULL,
    generated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_advice_snapshot_generated_at ON advice_snapshot(generated_at);


-- =============================================================================
-- SEÇÃO H — Sincronização e operação (Fase 2/7)
-- =============================================================================

-- webhook_event: idempotência de webhook (SPEC 4.3) — guarda o eventId
-- recebido e ignora reprocessamento pela unique constraint.
CREATE TABLE webhook_event (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_event_id VARCHAR(120) NOT NULL,
    event_type      VARCHAR(60) NOT NULL,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_webhook_event_provider_event_id UNIQUE (provider_event_id)
);

-- sync_log: status/duração/quantidade/erro de cada sync (seção 6) — uma
-- conta que falha não pode derrubar o sync das outras, e este log é como
-- você audita isso depois.
CREATE TYPE sync_status AS ENUM ('SUCCESS', 'PARTIAL_FAILURE', 'FAILURE');

CREATE TABLE sync_log (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id           UUID NOT NULL REFERENCES account(id),
    status                sync_status NOT NULL,
    started_at            TIMESTAMPTZ NOT NULL,
    finished_at            TIMESTAMPTZ,
    new_transaction_count  INTEGER NOT NULL DEFAULT 0,
    error_message          TEXT
);

CREATE INDEX ix_sync_log_account ON sync_log(account_id);


-- =============================================================================
-- O que vira Flyway V1 (Fase 0) — só a fundação
-- =============================================================================
-- institution, account, category (sem categorization_rule/llm cache ainda),
-- bank_transaction — o mínimo para cadastro manual de transação ponta a
-- ponta (entregável da Fase 1). Tudo o resto entra na migration da fase
-- que o usa: statement e internal_transfer na Fase 2, categorization_rule
-- e llm_categorization_cache na Fase 3, seção D e E inteiras na Fase 4,
-- budget na Fase 5, seção G na Fase 6, webhook_event/sync_log na Fase 2.
