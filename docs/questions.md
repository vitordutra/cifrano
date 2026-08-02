# Ambiguidades que mudam o modelo de dados

Conforme a seção 15 do `SPEC.md`: antes de qualquer migration, listo aqui toda ambiguidade que encontrei na leitura e que muda o schema. Cada item tem o que está ambíguo, por que isso afeta o modelo de dados, e minha recomendação com o motivo. Dois pontos que surgiram na conversa já viraram decisão sua e estão registrados no `SPEC.md` (seção 4.4, NuConta na seção 1) — não repito a pergunta aqui, só a consequência de schema.

---

## 1. Cartão de crédito é uma `Account` ou precisa de uma entidade de fatura?

A seção 5.2 detecta pagamento de fatura por "valor igual ao total da fatura fechada". Isso pressupõe saber quando a fatura fecha, quanto ela soma, e quando vence — nenhuma tabela do SPEC guarda isso.

**Por que muda o schema:** sem uma tabela de fatura, "total da fatura fechada" não existe como valor consultável; a regra 5.2 vira comparação contra a soma das transações do cartão no período, calculada toda vez, sem data de fechamento/vencimento para ancorar.

**Recomendação:** modelar `Account` com `type = CREDIT_CARD` normalmente (é só mais um tipo de conta, mesma tabela), e criar `statement` (fatura) como tabela própria: `account_id`, `closing_date`, `due_date`, `total_amount` (calculado ou snapshot no fechamento), `status`. *Fatura* — no código `statement` — é o agrupamento das compras do cartão dentro de um ciclo, do fechamento anterior ao próximo; é o que você recebe para pagar. Sem essa tabela, a seção 5.2 fica sem como comparar "valor pago" contra "valor fechado" de forma confiável quando há atraso, juros ou pagamento parcial.

## 2. Moeda: por transação ou única da aplicação?

Sistema single-user, tudo em BRL. A seção 4.1 diz que `Money` tem `BigDecimal amount` + `Currency currency`.

**Por que muda o schema:** se a moeda é sempre BRL, a coluna `currency` em toda tabela monetária é redundância que nunca varia — ou se antecipa a um requisito (multi-moeda) que não existe hoje.

**Recomendação:** manter `Currency` no value object `Money` (é barato e o código fica correto por construção), mas **não** persistir uma coluna `currency` por linha — fixar BRL como constante da aplicação e não gravar no banco. Se um dia houver conta em outra moeda, isso é mudança de schema explícita, não campo morto esperando ser usado.

## 3. `transactionDate` e `purchaseDate`: as duas são obrigatórias?

A seção 4.2 distingue as duas porque em cartão de crédito elas divergem, e a conciliação (seção 8) usa `purchaseDate`.

**Por que muda o schema:** se `purchaseDate` pode ser nula (o provedor não informa em todo tipo de transação — ex: PIX, TED, débito automático, onde só existe uma data), toda consulta que usa `purchaseDate` precisa de fallback para `transactionDate`.

**Recomendação:** `transactionDate` obrigatória (`NOT NULL`), `purchaseDate` opcional. Regra de aplicação: onde `purchaseDate` for nula, ela é a mesma que `transactionDate` — nunca deixar a conciliação tratar "sem data de compra" como "sem data".

## 4. Valores de `source` na transação

A seção 6.1 fala em `source = SCREENSHOT` e menciona Pluggy como fonte automática, mas não lista o enum completo.

**Recomendação:** `PLUGGY`, `FILE` (importação OFX/CSV/QIF), `SCREENSHOT`, `MANUAL` (digitada por você na UI). `supersededBy` é auto-relacionamento (`superseded_by_id` apontando para `transaction.id`, nulável), conforme o mecanismo da seção 6.1: a transação perdedora nunca é apagada, só marcada.

## 5. Categoria hierárquica: auto-relacionamento ou duas tabelas?

Seção 9: hierarquia de dois níveis (Alimentação → Supermercado/Restaurante/Delivery).

**Por que muda o schema:** duas tabelas (`category` + `subcategory`) tornam o segundo nível uma entidade diferente, com FK e queries diferentes; auto-relacionamento mantém uma tabela só, mais simples de consultar em qualquer nível.

**Recomendação:** auto-relacionamento — `category.parent_id` (nulável, aponta para `category.id`) com `CHECK` garantindo profundidade máxima 2 (uma categoria com `parent_id` não nulo não pode ser pai de outra). Também decidido na mesma linha de raciocínio da A1c: `category.code` (estável, em inglês, usado por regra e relatório) + `category.name` (rótulo em português, editável na UI) — ver seção sobre idioma no `CLAUDE.md`.

## 6. Item de nota fiscal: categoria própria ou herdada da transação?

Seção 9 diz que "cada item também é categorizado", com exemplo de uma compra dividida em 60/25/15% entre categorias.

**Recomendação (confirmação, não decisão nova):** `receipt_item.category_id` é independente de `transaction.category_id`. A transação carrega a categoria "principal" ou mais frequente entre os itens (para telas que não têm o drill-down), mas o relatório por item sempre soma pela categoria do item, nunca assume que todos os itens têm a categoria da transação.

## 7. Fila de revisão manual: tabela genérica ou uma por domínio?

As seções 5.1 (transferência ambígua), 6.1 (duplicata cruzada ambígua) e 8 (conciliação ambígua) mandam casos incertos para revisão, cada uma com um formato de candidato diferente (par de transações, transação x manual, nota x transação).

**Por que muda o schema:** uma tabela genérica (`review_task` com `type` + payload) evita duplicar estrutura de fila em três lugares, mas o payload heterogêneo fica menos consultável em SQL puro (é preciso saber o `type` antes de interpretar o resto). Três tabelas específicas são mais fáceis de indexar e consultar, mas repetem o conceito de "pendente, aceitar, rejeitar" três vezes.

**Recomendação:** três tabelas específicas — `internal_transfer_candidate`, `manual_entry_duplicate_candidate`, `receipt_reconciliation_candidate` — cada uma com FKs reais para as entidades que ela compara (em vez de um payload solto) e uma coluna `status` (`PENDING`/`CONFIRMED`/`REJECTED`) comum às três. É mais SQL para escrever agora, mas cada consulta de revisão sai direta, com `JOIN` normal, e o "aceitar"/"rejeitar" de cada fila tem exatamente os campos que aquele domínio precisa — nenhuma tem que carregar um JSON genérico para saber o que está comparando.

## 8. `Money` na Fase 0 ou na Fase 1?

A seção 14 lista `Money` como entregável da **Fase 0**, mas o texto da Fase 1 diz "a armadilha do `BigDecimal.equals` aparece aqui, no `Money`" — sugerindo que `Money` nasce na Fase 1.

**Recomendação:** construir `Money` inteiro na Fase 0, com a armadilha do `equals` demonstrada ali (é exatamente o tipo de coisa que faz sentido resolver antes de qualquer entidade usar `Money` como campo). A menção na Fase 1 eu leio como "a armadilha *aparece* no capítulo de aprendizado ligado ao `Money`", não como "o `Money` é escrito só na Fase 1" — mas é sua decisão, porque muda a ordem dos entregáveis.

## 9. `bank_transaction` em vez de `transaction`?

`transaction` é palavra reservada no padrão SQL (embora o Postgres aceite como identificador sem aspas, sem conflito).

**Recomendação:** usar `bank_transaction` mesmo assim. Motivo prático, não teórico: `TRANSACTION` aparece com frequência em ferramentas de client SQL, ORMs e em comandos como `BEGIN TRANSACTION` — manter esse nome fora do caminho evita qualquer ambiguidade visual ou de autocomplete no dia a dia, mesmo sem erro de sintaxe hoje. O DDL proposto (próximo documento) já usa esse nome; se você preferir `transaction` puro, é uma troca de nome antes da `V1`, sem custo.

---

Aguardando sua revisão antes de gerar `V1__create_foundation.sql`.
