-- V1: fundação do schema — o mínimo para cadastrar e listar uma transação
-- manual ponta a ponta (entregável da Fase 1). O restante do modelo
-- (fatura de cartão, transferência interna, notas fiscais, regras de
-- categorização, orçamento, perfil financeiro...) entra em migrations
-- futuras, uma por fase, nunca alterando esta. O modelo completo, revisado
-- antes desta migration existir, está documentado em docs/schema-proposto.sql.
--
-- gen_random_uuid() é nativo do Postgres desde a versão 13 — não precisa de
-- `CREATE EXTENSION pgcrypto`, que era necessário em versões anteriores.

CREATE TABLE institution (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(120) NOT NULL,
    provider_code   VARCHAR(60),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE account_type AS ENUM ('CHECKING', 'SAVINGS', 'CREDIT_CARD', 'BENEFIT');
CREATE TYPE fund_type AS ENUM ('GENERAL', 'RESTRICTED');

CREATE TABLE account (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id          UUID NOT NULL REFERENCES institution(id),
    name                    VARCHAR(120) NOT NULL,
    type                    account_type NOT NULL,
    fund_type               fund_type NOT NULL DEFAULT 'GENERAL',
    provider_account_id     VARCHAR(120),
    last_known_balance      NUMERIC(15,2),
    currency                CHAR(3) NOT NULL DEFAULT 'BRL',
    last_synced_at          TIMESTAMPTZ,
    active                  BOOLEAN NOT NULL DEFAULT true,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_account_provider_account_id UNIQUE (provider_account_id)
);

CREATE INDEX ix_account_institution ON account(institution_id);

-- category: hierarquia de dois níveis (SPEC seção 9), auto-relacionamento.
-- code é o identificador estável em inglês (usado por regra e relatório);
-- name é o rótulo em português, editável na UI.
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

CREATE INDEX ix_category_parent ON category(parent_id);

-- Profundidade máxima 2: uma categoria que já tem parent_id não pode virar
-- pai de outra. Um CHECK comum não resolve isso — CHECK no Postgres só
-- enxerga a linha sendo gravada, não consegue consultar se o parent_id
-- referenciado já tem um parent_id próprio (docs/questions.md, item 5).
CREATE FUNCTION check_category_depth() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parent_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM category WHERE id = NEW.parent_id AND parent_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'category % already has a parent, cannot become a parent itself', NEW.parent_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_category_max_depth
    BEFORE INSERT OR UPDATE ON category
    FOR EACH ROW EXECUTE FUNCTION check_category_depth();

-- bank_transaction: um lançamento bancário ou manual. Chamada de
-- bank_transaction, não transaction, para nunca colidir visualmente com a
-- palavra reservada SQL TRANSACTION (docs/questions.md, item 9).
--
-- Esta versão cobre só o necessário para a Fase 1 (cadastro manual ponta a
-- ponta): sem statement_id (a tabela statement só existe a partir da Fase
-- 2) e sem superseded_by_id (deduplicação cruzada é Fase 2). Ambos entram
-- por ALTER TABLE numa migration futura, quando a feature que os usa for
-- implementada.
CREATE TYPE transaction_source AS ENUM ('PLUGGY', 'FILE', 'SCREENSHOT', 'MANUAL');

CREATE TABLE bank_transaction (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id              UUID NOT NULL REFERENCES account(id),
    category_id             UUID REFERENCES category(id),

    -- Convenção de sinal (SPEC 4.1): despesa negativa, receita positiva.
    amount                  NUMERIC(15,2) NOT NULL,
    currency                CHAR(3) NOT NULL DEFAULT 'BRL',
    description             VARCHAR(300) NOT NULL,

    -- transactionDate: quando foi contabilizada. purchaseDate: quando a
    -- compra aconteceu (nulável — nem todo lançamento tem as duas datas).
    -- O fallback entre as duas é feito por um método de domínio
    -- (BankTransaction.effectivePurchaseDate()), nunca por SQL
    -- (docs/questions.md, item 3).
    transaction_date        TIMESTAMPTZ NOT NULL,
    purchase_date           TIMESTAMPTZ,

    -- Idempotência (SPEC 4.3). Par nulável: transações MANUAL não têm
    -- external_id nem provider_account_id, e o Postgres não trata NULL
    -- como igual a NULL numa unique constraint — múltiplas linhas com o
    -- par (NULL, NULL) são permitidas, só pares preenchidos e iguais
    -- colidem.
    external_id             VARCHAR(120),
    provider_account_id     VARCHAR(120),

    -- Parcelamento (seção 5.3).
    installment_number      INTEGER,
    total_installments      INTEGER,
    purchase_group_id       UUID,

    excluded_from_reports   BOOLEAN NOT NULL DEFAULT false,

    source                  transaction_source NOT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

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
CREATE INDEX ix_bank_transaction_transaction_date ON bank_transaction(transaction_date);
