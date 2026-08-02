# Ambiguidades que mudam o modelo de dados

Conforme a seção 15 do `SPEC.md`: antes de qualquer migration, listo aqui toda ambiguidade que encontrei na leitura e que muda o schema. Cada item tem o que está ambíguo, por que isso afeta o modelo de dados, minha recomendação com o motivo, e a **decisão** que você tomou. Dois pontos que surgiram na conversa já viraram decisão sua e estão registrados no `SPEC.md` (seção 4.4, NuConta na seção 1) — não repito a pergunta aqui, só a consequência de schema.

**Todos os itens abaixo foram decididos.** `schema-proposto.sql` já reflete as decisões.

---

## 1. Cartão de crédito é uma `Account` ou precisa de uma entidade de fatura?

A seção 5.2 detecta pagamento de fatura por "valor igual ao total da fatura fechada". Isso pressupõe saber quando a fatura fecha, quanto ela soma, e quando vence — nenhuma tabela do SPEC guarda isso.

**Por que muda o schema:** sem uma tabela de fatura, "total da fatura fechada" não existe como valor consultável; a regra 5.2 vira comparação contra a soma das transações do cartão no período, calculada toda vez, sem data de fechamento/vencimento para ancorar.

**Recomendação:** modelar `Account` com `type = CREDIT_CARD` normalmente (é só mais um tipo de conta, mesma tabela), e criar `statement` (fatura) como tabela própria: `account_id`, `closing_date`, `due_date`, `total_amount` (snapshot no fechamento), `status`. *Fatura* — no código `statement` — é o agrupamento das compras do cartão dentro de um ciclo, do fechamento anterior ao próximo; é o que você recebe para pagar.

**Decisão: criar `statement`.**

## 2. Moeda: por transação ou única da aplicação?

Sistema single-user, tudo em BRL. A seção 4.1 diz que `Money` tem `BigDecimal amount` + `Currency currency`.

**Por que muda o schema:** se a moeda é sempre BRL, a coluna `currency` em toda tabela monetária é redundância que nunca varia — ou se antecipa a um requisito (multi-moeda) que não existe hoje.

**Minha recomendação era não persistir.** Você decidiu diferente.

**Decisão: persistir `currency` em toda tabela monetária.** `CHAR(3) NOT NULL DEFAULT 'BRL'`, uma coluna por tabela que tem valor monetário (não uma por coluna de valor — uma tabela com `unit_price` e `total_price`, como `receipt_item`, usa a mesma moeda para as duas). Atualizado em `schema-proposto.sql`.

## 3. `transactionDate` e `purchaseDate`: as duas são obrigatórias?

A seção 4.2 distingue as duas porque em cartão de crédito elas divergem, e a conciliação (seção 8) usa `purchaseDate`.

**Por que muda o schema:** se `purchaseDate` pode ser nula (o provedor não informa em todo tipo de transação — ex: PIX, TED, débito automático, onde só existe uma data), toda consulta que usa `purchaseDate` precisa de fallback para `transactionDate`.

**Decisão: `purchaseDate` nulável, com fallback centralizado no domínio.** `transactionDate` obrigatória (`NOT NULL`), `purchaseDate` opcional. Em vez de espalhar `COALESCE(purchase_date, transaction_date)` pelas consultas SQL, o domínio Java expõe um método `effectivePurchaseDate()` na entidade `BankTransaction`, e todo código que precisa "a data que importa para conciliação" chama esse método — nunca lê a coluna `purchase_date` direto quando a intenção é essa. Isso evita o risco de uma query esquecer o fallback e a conciliação falhar silenciosamente para transações Pix (que normalmente não têm `purchaseDate`).

## 4. Valores de `source` na transação

A seção 6.1 fala em `source = SCREENSHOT` e menciona Pluggy como fonte automática, mas não lista o enum completo.

**Decisão: `PLUGGY`, `FILE` (importação OFX/CSV/QIF), `SCREENSHOT`, `MANUAL` (digitada por você na UI).** `supersededBy` é auto-relacionamento (`superseded_by_id` apontando para `bank_transaction.id`, nulável), conforme o mecanismo da seção 6.1: a transação perdedora nunca é apagada, só marcada.

## 5. Categoria hierárquica: auto-relacionamento ou duas tabelas?

Seção 9: hierarquia de dois níveis (Alimentação → Supermercado/Restaurante/Delivery).

**Por que muda o schema:** duas tabelas (`category` + `subcategory`) tornam o segundo nível uma entidade diferente, com FK e queries diferentes; auto-relacionamento mantém uma tabela só, mais simples de consultar em qualquer nível.

**Decisão: auto-relacionamento**, com `category.parent_id` (nulável, aponta para `category.id`), `category.code` (estável, em inglês, usado por regra e relatório) e `category.name` (rótulo em português, editável na UI).

**Correção sua sobre a validação de profundidade:** eu tinha proposto um `CHECK` garantindo profundidade máxima 2. Isso não funciona — `CHECK` no Postgres só enxerga a linha sendo inserida ou atualizada, não pode consultar se o `parent_id` referenciado já tem um `parent_id` próprio. A validação correta é um **`TRIGGER`** (`BEFORE INSERT/UPDATE` em `category`) que consulta a linha do pai antes de aceitar, e rejeita se o pai já for filho de outra categoria. Corrigido em `schema-proposto.sql`.

## 6. Item de nota fiscal: categoria própria ou herdada da transação?

Seção 9 diz que "cada item também é categorizado", com exemplo de uma compra dividida em 60/25/15% entre categorias.

**Decisão: categoria independente.** `receipt_item.category_id` é independente de `transaction.category_id`. A transação carrega a categoria "principal" ou mais frequente entre os itens (para telas que não têm o drill-down), mas o relatório por item sempre soma pela categoria do item, nunca assume que todos os itens têm a categoria da transação.

## 7. Fila de revisão manual: tabela genérica ou uma por domínio?

As seções 5.1 (transferência ambígua), 6.1 (duplicata cruzada ambígua) e 8 (conciliação ambígua) mandam casos incertos para revisão, cada uma com um formato de candidato diferente (par de transações, transação x manual, nota x transação).

**Decisão: três tabelas específicas** — `internal_transfer_candidate`, `manual_entry_duplicate_candidate`, `receipt_reconciliation_candidate` — cada uma com FKs reais para as entidades que ela compara e uma coluna `status` (`PENDING`/`CONFIRMED`/`REJECTED`) comum às três.

## 8. `Money` na Fase 0 ou na Fase 1?

A seção 14 lista `Money` como entregável da **Fase 0**, mas o texto da Fase 1 diz "a armadilha do `BigDecimal.equals` aparece aqui, no `Money`" — sugerindo que `Money` nasce na Fase 1.

**Decisão: `Money` completo na Fase 0**, com a armadilha do `equals` demonstrada ali (mostrando o teste falhando antes da correção, conforme seção 3.1).

## 9. `bank_transaction` em vez de `transaction`?

`transaction` é palavra reservada no padrão SQL (embora o Postgres aceite como identificador sem aspas, sem conflito).

**Decisão: `bank_transaction`.** Evita ambiguidade visual em clientes SQL, ORMs e autocomplete, mesmo sem erro de sintaxe hoje.

---

Todas as decisões estão refletidas em `schema-proposto.sql`. Próximo passo: revisar `discordancias.md`, se ainda não revisado, e então liberar a Fase 0.
