# O que eu discordo ou acho arriscado no SPEC

Conforme pedido na seção 15: retorno direto, sem diplomacia. Isso não são bloqueios — são pontos técnicos que eu recomendo revisar antes ou durante a fase em que aparecem. Se você discordar de mim, seguimos com sua decisão; é só para você decidir de olhos abertos.

---

## 1. Detecção de pagamento de fatura por padrão de texto na descrição é o critério mais fraco dos três (seção 5.2)

A seção 5.2 lista três sinais para detectar pagamento de fatura: conta destino `CREDIT_CARD`, valor igual ao total da fatura fechada, e descrição contendo padrão de pagamento. O terceiro é o problema — descritor de pagamento de fatura varia por banco, muda sem aviso, e "conter padrão" é exatamente o tipo de heurística frágil que a seção 8 evita deliberadamente ao preferir *score* a regra binária.

Com a tabela `statement` que propus em `schema-proposto.sql`, o segundo critério (valor bate com o total fechado) já é suficiente sozinho, combinado com o primeiro (conta destino é `CREDIT_CARD` do tipo esperado). Meu voto: descarte o terceiro critério como sinal de decisão e use-o só como reforço de exibição na UI ("por que marcamos isso como pagamento de fatura"), nunca como parte da lógica de detecção. Regra decidida por string de descrição é a que quebra primeiro quando o banco muda o layout do extrato.

## 2. A raspagem de HTML da SEFAZ (seção 7.1) é a dependência mais frágil do sistema, e é a feature principal

Você chamou notas fiscais de "a feature principal" (seção 7). O caminho primário dela depende de fazer parse de HTML de um portal governamental estadual que você não controla, sem contrato de API, sem SLA, sujeito a CAPTCHA, mudança de layout ou bloqueio por taxa de acesso sem aviso — e isso multiplicado por UF (você já vai ter dois parsers, MA e SP, cada um podendo quebrar independente do outro).

O SPEC já manda isolar cada UF e falhar de forma explícita, o que é a mitigação certa. O que falta, e eu recomendo adicionar: **cache permanente do resultado parseado por chave de acesso**. Uma nota já lida com sucesso nunca precisa ser buscada de novo — isso reduz a superfície de exposição ao portal (menos chance de bloqueio por volume) e blinda o histórico contra o dia em que o parser de uma UF para de funcionar. Sem isso, um problema no scraper da SEFAZ-SP não só impede notas novas, arrisca também re-open de notas antigas se algum fluxo futuro precisar re-consultar.

## 3. Custo de chamada a LLM não tem controle nenhum no SPEC (seção 11.7 só cobre privacidade)

Três pontos diferentes do sistema chamam API de modelo de linguagem: categorização de último recurso (seção 9), extração por visão (seção 7.2), e o assistente financeiro inteiro (seção 11). A seção 11.7 fala só de privacidade — "quais dados são enviados" — e nada sobre quanto isso custa por mês nem sobre o que acontece se um bug gerar uma chamada em loop (um retry mal configurado, uma tela que dispara a mesma extração de imagem duas vezes).

Recomendo: uma tabela simples de `llm_call_log` (provedor, tokens, custo estimado, timestamp) e um limite mensal configurável que, se estourado, degrada graciosamente — categorização cai para "sem sugestão" em vez de erro, extração de imagem para de processar e avisa. É pouco código e evita a situação de single-user sem observabilidade nenhuma sobre gasto de API — que é irônico num sistema que existe para controlar gasto.

## 4. A regra de auto-vínculo da conciliação não define o caso de candidato único (seção 8)

"score ≥ 0.85 **e** o segundo melhor candidato < 0.60 → vincula automaticamente." Isso pressupõe que sempre existe um segundo candidato para comparar. Quando há **só um** candidato com score ≥ 0.85, a regra como está escrita fica ambígua: um segundo candidato inexistente satisfaz "< 0.60" (nada é ≥ 0.60) ou trava a decisão por falta de comparação?

Vou implementar como: ausência de segundo candidato conta como score 0 para efeito da comparação — ou seja, candidato único com score ≥ 0.85 vincula automaticamente. É a leitura mais natural e evita que a nota mais comum do sistema (comprei em um lugar, num dia, com um valor exato — o caso fácil) caia desnecessariamente na fila de revisão manual. Aviso aqui para você corrigir se a intenção era outra.

## 5. `record` para entidade JPA não funciona, e a seção 2 do SPEC pode ser lida como se funcionasse

A seção 2 diz "Sem Lombok — use records e classes normais", sem distinguir onde cada um se aplica. Vale deixar explícito porque é um erro comum de quem está aprendendo Java+JPA: **entidade JPA nunca é `record`**. Hibernate precisa de um construtor sem argumentos e de conseguir alterar os campos por reflection para *dirty checking* (seção 3.1 já promete explicar isso) — um `record` é imutável por definição e não tem construtor vazio. Vou usar `record` para os value objects de domínio (`Money`, DTOs de request/response, o payload do snapshot) e classes normais, mutáveis, só em `adapter/out` para as entidades `@Entity`. É exatamente o que a arquitetura hexagonal da seção 3 já separa — só estou deixando escrito para não virar suposição implícita no meio do código.
