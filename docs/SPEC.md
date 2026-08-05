# Cifrano — Sistema de Finanças Pessoais (Java + Next.js)

O nome do projeto é **Cifrano**. Não é palavra inventada: *cifrano* é o nome do símbolo monetário de duas barras verticais — o parente do cifrão. Use-o no repositório, no pacote raiz, no título da aplicação e no PWA.

Você vai construir um sistema fullstack de gestão de finanças pessoais para **um único usuário** (eu), rodando self-hosted numa VPS. Leia este documento inteiro antes de escrever qualquer código.

---

## 0. Regras de trabalho (importante)

- **Trabalhe em fases.** As fases estão no final deste documento. Ao terminar cada fase, pare, rode os testes e me apresente um resumo curto do que foi feito e o que precisa da minha ação (ex: pegar credencial). Só siga para a próxima fase quando eu mandar.
- **Commits pequenos e atômicos.** Um commit por unidade lógica de trabalho — uma entidade, um caso de uso, um teste, um refactor, uma migration —, nunca um commit gigante no fim da fase. Quero conseguir ler o `git log` de cima a baixo e reconstruir o raciocínio do projeto passo a passo, como se fosse um tutorial. Use Conventional Commits (`feat:`, `test:`, `refactor:`, `chore:`) e escreva um **corpo de mensagem explicando o porquê da decisão** — o diff já mostra o quê. Se um commit precisa de "e" na descrição, provavelmente são dois commits.
- **Nada de `Co-authored-by` nem de qualquer assinatura ou menção a ferramenta de IA** nas mensagens de commit. Sem rodapé, sem emoji de robô, sem "generated with". A mensagem termina no conteúdo técnico.
- **Não invente contratos de API externa.** Antes de integrar com Pluggy, use WebFetch em `https://docs.pluggy.ai` e confirme os endpoints, os nomes dos campos e o formato dos webhooks. Se a doc divergir deste documento, a doc vence — e me avise.
- **Não superengenheire.** Sem microserviços, sem Kafka, sem service mesh, sem CQRS. Um monólito modular bem feito, um Postgres, um docker-compose.
- **Escreva testes de verdade** (Testcontainers para repositório, unitários para regra de negócio). Não escreva testes que só verificam mock. **Nomes de teste descrevem a regra, não o método**: `creditCardBillPaymentIsNotAnExpense()` em vez de `testDetect()`. Quero conseguir ler a lista de testes de uma classe e entender o que o sistema faz sem abrir o código. As regras completas e o que eu quero aprender sobre teste estão na **seção 12**.
- Crie e mantenha um `CLAUDE.md` na raiz com decisões, comandos e convenções, e um `docs/adr/` com as decisões arquiteturais relevantes.
- Perguntas em vez de suposições silenciosas: se algo estiver ambíguo e mudar o modelo de dados, pergunte.
- **Todo o código é em inglês** — nomes de pacote, classe, método, variável, enum, constante, nomes de teste, mensagens de exceção, chaves de configuração, rotas e campos de JSON. **O banco também**: DDL e DML — tabelas, colunas, constraints, índices, valores de enum persistidos e arquivos de migration. **A documentação (`docs/`) é em português**, porque é material de estudo; o glossário faz a ponte entre o termo em português e o identificador em inglês correspondente. Mensagens de commit em inglês. Nome de teste descreve a regra de negócio, não o método: `creditCardBillPaymentIsNotAnExpense()`, nunca `testDetect()`.

### Meu perfil — calibre suas explicações por isso

Sou engenheiro backend e trabalho com integração de pagamentos na prática, mas **não com o vocabulário financeiro e contábil** — termos como conciliação, liquidação, regime de competência, provisão ou estorno eu não sei de cor. E **estou estudando as duas pontas da stack**: este projeto é o meu principal veículo de aprendizado.

- **Java e Spring:** no Spring sei o básico (injeção de dependência, `@RestController`, `@Service`, JPA superficial) e na linguagem tem bastante coisa que ainda não domino — generics avançados, concorrência, `CompletableFuture`, sealed types, `Optional` usado direito, streams mais complexos, o modelo de exceções.
- **React e Next.js:** praticamente do zero. Sei que a interface é feita de componentes e é só isso — não lembro o que são props nem o que o `useState` faz. Não conheço nenhum outro hook, não sei a diferença entre Server e Client Component, não sei o que o App Router faz, não sei o que é hidratação, nunca usei TanStack Query, e o modelo mental de renderização do React não existe na minha cabeça. Considere que eu não sei nada de React além da palavra "componente" e não vou fingir que sei.

Ou seja: preciso aprender **três coisas ao mesmo tempo** — backend, frontend e a lógica de negócio. Trate as três com o mesmo cuidado. Na parte de frontend, assuma menos conhecimento prévio do que na de backend.

Isso muda como você deve trabalhar:

- **Explique a regra de negócio antes de implementá-la.** Toda vez que for escrever uma classe que contém lógica de domínio, comece descrevendo em texto: qual fato do mundo real ela representa, que problema resolve, que casos de borda existem, e o que acontece se ela estiver errada. Só depois escreva o código. Exemplo do que eu quero ler antes do `InternalTransferDetector`: *"Quando você move dinheiro entre suas próprias contas, o mesmo evento aparece duas vezes — saída numa conta, entrada na outra. Nenhuma das duas é despesa. Se não filtrar isso, um relatório que devia mostrar R$ 3.000 de gasto mensal mostra R$ 5.500. O caso de borda é quando duas transferências do mesmo valor ocorrem na mesma janela: aí não dá para saber qual casa com qual, e adivinhar é pior que perguntar."*
- **Nomeie as coisas com o termo real do domínio e explique o termo.** Se a classe se chama `SettlementReconciler`, escreva o que é liquidação e o que é conciliação. Prefira o vocabulário correto do setor a nomes genéricos como `Processor` ou `Manager` — mas nunca use um termo sem me ensinar o que significa na primeira vez que aparecer.
- **Mantenha `docs/dominio/glossario.md`** com todo termo financeiro ou contábil que aparecer no projeto: definição em uma frase, exemplo concreto com números do meu caso real, e onde ele aparece no código. Adicione ao glossário no mesmo commit em que o termo entra no código, nunca depois.
- **Separe claramente o que é decisão técnica do que é regra de negócio.** Quando você definir um número — janela de ±3 dias, score de 0.85, tolerância de R$ 0,50 —, diga se ele veio de uma restrição real do mundo (fatura fecha uma vez por mês) ou de uma escolha arbitrária minha que pode ser ajustada. Números arbitrários vão para configuração, não hardcoded.
- **Ensine enquanto constrói.** Sempre que introduzir algo que eu provavelmente não conheço — uma anotação, um recurso da linguagem, um padrão, uma escolha de biblioteca —, explique em 3-5 linhas: o que faz, por que aqui, o que aconteceria sem isso, e qual é a alternativa comum. Coloque isso no corpo do commit ou em `docs/`, não como comentário no código.
- **Comente o não óbvio, nunca o óbvio.** `// incrementa o contador` é lixo. `// Jaro-Winkler em vez de Levenshtein: prefixo igual pesa mais, e descritor de cartão vem truncado` é exatamente o que eu quero ler.
- **Mostre o porquê, não só o resultado.** Se usar `@Transactional(readOnly = true)`, diga o que muda. Se escolher `record` em vez de classe, diga por quê. Se usar injeção por construtor em vez de `@Autowired` no campo, diga o motivo.
- **Não me poupe da complexidade real.** Quero aprender a fazer certo, não a fazer fácil. Mas quando algo for genuinamente avançado, sinalize — "isto é avançado, o modelo mental é este" — em vez de deixar passar como se fosse trivial.
- **Se eu pedi algo que é má ideia, diga** e explique o motivo técnico. Retorno direto vale mais que diplomacia.
- **Ao final de cada fase, escreva `docs/aprendizado/fase-N.md`** em duas partes: (1) **Tecnologia** — os conceitos novos de Java/Spring que apareceram, em ordem de importância, cada um com explicação curta, o trecho do projeto onde aparece e link para a documentação oficial; (2) **Negócio** — as regras de domínio que a fase implementou, escritas em português comum, como se você explicasse para alguém que não vai ler o código. É o material que eu vou estudar depois.

Uma pergunta minha do tipo "por que você fez assim?" é curiosidade genuína, não crítica velada. Responda como explicação técnica, não corrigindo o código.

---

## 1. Objetivo

Registrar automaticamente 100% dos meus gastos, com o mínimo de trabalho manual, e me dar visibilidade real de para onde meu dinheiro vai — inclusive **item a item** dentro de cada compra.

Duas fontes de dados:

1. **Extratos bancários** (automático, via agregador de Open Finance)
2. **Notas fiscais** (foto/QR code, que enriquece a transação bancária com os itens da compra)

Minhas contas: **Mercado Pago** (principal), **Banco do Brasil**, **Nubank** (cartão de crédito **e NuConta**), **Swile** (benefícios). Uma instituição pode ter mais de uma conta — é o caso do Nubank, com cartão de crédito e conta corrente (NuConta) na mesma instituição.

---

## 2. Stack (fixa, não substitua)

Anotei o que cada peça faz porque várias delas eu ainda não conheço. Se alguma anotação minha estiver errada ou incompleta, me corrija na primeira vez que a ferramenta aparecer no código.

**Backend**
- **Java 21** + **Spring Boot 4.1.x** — linguagem e framework. (Originalmente fixado em 3.5.x; trocado antes da Fase 0 porque a linha 3.5 chegou ao fim de vida open-source em 30/06/2026, sem mais patch de segurança gratuito — ver `docs/discordancias.md`.)
- **Maven** (não use Gradle) — gerenciador de dependências e build. É o `pom.xml`.
- **PostgreSQL 16** — o banco de dados.
- **Flyway** — versionamento de schema do banco. Em vez de alterar tabelas na mão, cada mudança vira um arquivo SQL numerado (`V1__create_transactions.sql`, `V2__add_installments.sql`) que roda uma vez e fica registrado numa tabela de controle. Isso torna o banco reproduzível: outra máquina, ou a VPS, chega ao mesmo estado rodando as mesmas migrations na mesma ordem. **Regra que decorre disso: nunca altere uma migration já aplicada — crie uma nova.**
- **Spring Data JPA** — mapeia classes Java para tabelas e gera as queries.
- **springdoc-openapi** — gera a documentação da API (OpenAPI/Swagger) a partir do código.
- **Resilience4j** — retry e circuit breaker nas chamadas externas, para uma API fora do ar não derrubar o resto.
- **JUnit 5** + **AssertJ** — framework de teste e biblioteca de asserções.
- **Testcontainers** — sobe um Postgres real em Docker durante os testes, em vez de banco em memória. Testa contra o banco de verdade.
- **ArchUnit** — testes que verificam regras de arquitetura, não comportamento. Ex: falhar o build se uma classe de `domain` importar algo do Spring.
- Sem Lombok — use records e classes normais.

**Frontend**
- **Next.js 16 (App Router)** — framework React com renderização no servidor. (Originalmente fixado em 15; trocado antes do scaffold porque o 15 só recebe suporte até 21/10/2026, e a Fase 5 — onde o frontend passa a ser usado de verdade — só começa depois das fases 1-4. Diferente do Spring Boot 3.5, o 15 ainda não estava morto, mas nasceria perto do fim de vida — ver `docs/discordancias.md`.)
  - **Turbopack é o bundler padrão** do Next.js 16 (substituiu o Webpack como default) — não precisa configurar nada para isso, já vem assim no scaffold.
  - **React Compiler não é ligado.** Ele existe (opt-in via `next.config.ts`) e memoiza componentes automaticamente, evitando re-renderizações desnecessárias sem precisar de `useMemo`/`useCallback` escritos à mão. Não ligar é deliberado: quero entender o modelo de re-renderização do React manualmente antes de deixar uma ferramenta automatizar isso — ligar cedo demais esconderia exatamente o problema que a Fase 5 quer que eu aprenda a enxergar.
- **TypeScript strict** — JavaScript com tipos.
- **Tailwind CSS v4** — estilização por classes utilitárias direto na marcação.
- **shadcn/ui** — componentes prontos (botão, tabela, modal) que são copiados para o projeto em vez de instalados como dependência.
- **TanStack Query** — cuida dos dados vindos do servidor no cliente: cache, revalidação, estados de carregando/erro.
- **zod** — validação de dados em tempo de execução. Os tipos do TypeScript só existem enquanto você escreve o código: na hora de rodar, eles desaparecem, e o JSON que chega do backend pode ter qualquer formato sem ninguém reclamar. O zod define o formato esperado como um objeto de verdade, que existe em execução e é capaz de checar o dado que chegou. E o tipo do TypeScript é gerado a partir desse objeto, então você declara o formato uma vez só em vez de duas.
- **Recharts** — biblioteca de gráficos.
- **lucide-react** — ícones. **next-themes** — alternância entre tema claro e escuro.
- **PWA** (manifest + service worker) — faz o site instalável no celular e com acesso à câmera.

**Infra**
- **docker-compose** — sobe todos os serviços (postgres, backend, frontend, caddy) com um comando só, cada um em seu contêiner, numa rede interna onde eles se enxergam pelo nome.
- **Caddy** — o *reverse proxy*. Um **proxy** comum fica na frente de quem *faz* o pedido (a empresa põe um proxy e todo acesso à internet sai por ele). Um **reverse proxy** é o inverso: fica na frente de quem *responde*. Ele é o único serviço com porta aberta para a internet; toda requisição chega nele, ele decide para qual serviço interno encaminhar (`/api/*` para o backend, o resto para o frontend), repassa e devolve a resposta.

  Duas consequências, e são o motivo de existir:

  1. **Uma porta aberta em vez de três.** Sem ele eu precisaria expor `:3000` para o frontend e `:8080` para a API. Com ele, só a `:443`. Backend, frontend e Postgres ficam sem endereço acessível de fora — existem apenas dentro da rede do compose, alcançáveis pelo nome do serviço (`backend:8080`). Isso importa porque o Postgres vai guardar meu extrato bancário inteiro, e banco com porta exposta é varrido por bots em horas.
  2. **HTTPS automático.** O Caddy pede o certificado TLS ao Let's Encrypt sozinho na primeira subida e renova sozinho para sempre. Com nginx eu teria que instalar certbot, configurar renovação por cron e apontar caminhos de certificado. É por isso que quero Caddy e não nginx aqui.
- Deploy alvo: VPS Linux (Hetzner). Não use nada específico de cloud provider.

---

## 3. Arquitetura do backend

Monólito modular com arquitetura hexagonal. Um módulo Maven só (um `pom.xml`), mas pacotes com fronteiras rígidas validadas por ArchUnit:

```
com.cifrano
├── account/          # contas, instituições, saldos
├── transaction/      # transações, deduplicação, transferências internas
├── category/         # categorias, regras, motor de categorização
├── receipt/          # notas fiscais, itens, captura
├── reconciliation/   # casamento nota fiscal <-> transação
├── budget/           # orçamentos e metas
├── advice/           # perfil financeiro, snapshot, assistente de IA
├── sync/             # orquestração de sincronização, webhooks
└── shared/           # Money, tipos base, config
```

Cada módulo:
```
domain/      # entidades e regras puras — ZERO dependência de Spring ou JPA
application/ # casos de uso (services), define as interfaces (ports)
adapter/in/  # controllers REST, webhook handlers
adapter/out/ # repositórios JPA, clientes HTTP
```

**Regra que o ArchUnit deve garantir:** `domain` não importa nada de `org.springframework`, `jakarta.persistence` nem de outros módulos. Entidades JPA vivem em `adapter/out`, separadas do domínio, com mappers explícitos.

**Por que hexagonal aqui:** o provedor de dados bancários precisa ser trocável. Hoje é Pluggy; amanhã pode ser Belvo, ou uma integração direta com Open Finance, ou importação de OFX/CSV. Defina a porta `BankDataProvider` no domínio e implemente `PluggyBankDataProvider` e `OfxFileBankDataProvider` como adapters.

### 3.1 Como me ensinar backend e Java

Eu sei escrever Java que funciona. O que eu não tenho é o **porquê** por trás das escolhas intermediárias e avançadas, e é isso que quero tirar deste projeto. Vale o mesmo espírito da seção 10.4, com uma diferença: aqui eu tenho base, então pode ir mais fundo e mais rápido.

**Regra anti-mágica.** Spring faz muita coisa implicitamente, e código que funciona por magia que eu não entendo é código que eu não sei consertar. Toda vez que uma anotação fizer algo não óbvio, explique o **mecanismo**, não só o efeito. Não basta dizer "`@Transactional` abre uma transação" — quero saber que o Spring cria um proxy em volta do bean, que é por isso que chamar um método anotado de dentro da mesma classe não funciona, e que por padrão só faz rollback em `RuntimeException`.

**Não complique de propósito.** Não use recurso avançado só para me ensinar. Se a solução simples é a correta, use a simples e me diga qual seria a alternativa sofisticada e por que ela seria pior aqui — essa comparação ensina mais que o recurso em si.

**Mostre o erro antes da correção**, nas quatro armadilhas abaixo. Um commit com o problema, outro com a solução, cada um explicando o que aconteceu. Aprender por susto funciona:

1. **`BigDecimal.equals` vs `compareTo`** — `new BigDecimal("10.00").equals(new BigDecimal("10.0"))` é `false`, porque `equals` compara a escala. Isso vai me morder no `Money`. Mostre o teste falhando antes de corrigir.
2. **N+1 em JPA** — listar 500 transações e acessar a categoria de cada uma dispara 501 queries. Mostre o log de SQL antes e depois do `join fetch`.
3. **`LazyInitializationException`** — acessar uma relação lazy fora da transação. Mostre por que a solução não é `EAGER` em tudo nem `open-in-view` ligado.
4. **Timezone** — uma transação do dia 31 às 22h em São Paulo virando dia 1º do mês seguinte em UTC, e destruindo o fechamento mensal.

**Conceitos que eu quero ter entendido ao final, cada um explicado no momento em que aparecer no código** (não faça um tutorial solto — amarre ao ponto do projeto onde ele resolve um problema real):

- *Modelagem*: `record` vs classe, imutabilidade e cópia defensiva, `equals`/`hashCode` em value objects, enums com comportamento, sealed interfaces para modelar resultado e erro.
- *Linguagem*: `Optional` usado direito (nunca como campo ou parâmetro, nunca `.get()`), generics com limites, streams e `Collectors` — e quando **não** usar stream, que é quase sempre que a agregação deveria estar em SQL.
- *Erros*: checked vs unchecked, hierarquia de exceção própria, por que capturar `Exception` genérica esconde bug, onde tratar e onde deixar subir.
- *Concorrência*: o que `@Scheduled` e `@Async` fazem com threads, pool de conexão, o que acontece se dois syncs rodarem juntos, e por que a `unique constraint` do banco é a garantia real e não o `if` no código.
- *Tempo*: `Instant` vs `LocalDate` vs `ZonedDateTime`, e o que significa **persistir em UTC e converter só na borda**. *Borda* é a fronteira do sistema — os pontos onde o dado entra ou sai: a data que eu digito na tela, o JSON que o controller devolve, o payload que a Pluggy manda, o agrupamento do relatório mensal. Dentro do sistema (domínio, regras de negócio, banco) tudo é `Instant` em UTC, sem exceção e sem fuso embutido; a conversão para `America/Sao_Paulo` acontece **só** nesses pontos de entrada e saída. O motivo é evitar conversão parcial espalhada: se cada camada converte um pouquinho, você perde a noção de qual valor está em qual fuso, e uma conversão a mais desloca a transação em três horas — o bastante para uma compra do dia 31 às 22h cair no mês seguinte e furar o fechamento.
- *Spring*: comece por **bean** e **container**, que eu não domino.
  - **Bean** é um objeto cuja criação e ciclo de vida quem controla é o Spring, não o meu código. Em vez de eu escrever `new PluggyClient(...)`, eu marco a classe (`@Component`, `@Service`, `@Repository`) ou declaro um método `@Bean`, e o Spring instancia, resolve as dependências dela e a entrega pronta a quem precisar.
  - **Container** é o que guarda todos esses objetos e monta o grafo de dependências na ordem certa: se o `SyncService` precisa do `PluggyClient`, que precisa de um cliente HTTP, ele resolve a cadeia inteira sozinho. Isso é **inversão de controle** — quem decide como o objeto nasce é o framework, não quem o usa. Explique o que se ganha: trocar implementação (Pluggy por OFX), testar com dublê, configurar por ambiente.
  - **Escopo padrão é singleton** — existe uma instância só de cada bean, compartilhada pela aplicação inteira. Explique a consequência, que é a que morde: bean com estado mutável em campo é bug de concorrência esperando acontecer, porque duas requisições simultâneas mexem no mesmo objeto. Isso me atinge direto no sync agendado, e é o motivo de service ser sem estado.
  - **Injeção por construtor, nunca por campo** — com os motivos reais: o campo pode ser `final`, as dependências ficam visíveis na assinatura em vez de escondidas em anotações, dá para instanciar a classe num teste sem subir o Spring, e dependência circular estoura na subida em vez de passar silenciosamente.
  - Depois disso: `@ConfigurationProperties` em vez de `@Value` espalhado, e profiles.
- *JPA*: dirty checking, lazy vs eager, por que entidade não é DTO, e por que o mapeamento explícito da arquitetura hexagonal me protege disso.
- *Teste*: `@SpringBootTest` vs fatias (`@DataJpaTest`, `@WebMvcTest`) e o custo de subir o contexto inteiro à toa.

**Ao final de cada fase do backend, me proponha dois exercícios pequenos** para eu fazer sozinho no projeto: um caso de uso simples ou um teste, com o resultado esperado descrito e sem o código. Ler código pronto não fixa nada.

---

## 4. Decisões que já estão tomadas (não me pergunte, apenas implemente)

### 4.1 Dinheiro
- Nunca `double`/`float`. Coluna `NUMERIC(15,2)`, `BigDecimal` no Java.
- Crie um value object `Money` em `shared/domain` com `BigDecimal amount` + `Currency currency`, imutável, com `add`/`subtract`/`negate`/`isNegative`. Toda a aplicação usa `Money`, nunca `BigDecimal` cru.
- Convenção de sinal: **despesa é negativa, receita é positiva.** Sem exceção. Normalize isso na fronteira do adapter.

### 4.2 Tempo
- Persistir sempre `Instant` em UTC (`TIMESTAMPTZ`).
- Toda apresentação e todo agrupamento por mês/dia usa `America/Sao_Paulo`. Constante única em `shared`.
- Distinga `transactionDate` (quando a transação foi contabilizada) de `purchaseDate` (quando a compra aconteceu). Em cartão de crédito elas divergem, e o casamento com nota fiscal depende da segunda.

### 4.3 Idempotência

**Idempotente** é a operação que pode ser executada várias vezes com o mesmo resultado da primeira. É a propriedade mais importante aqui: eu vou rodar o sync de novo depois de um erro, o webhook da Pluggy vai chegar duplicado, e nada disso pode inventar transação.

- Toda transação tem `externalId` (o id do provedor) + `providerAccountId`, com **unique constraint** no par. Sincronização é sempre **upsert** por essa chave — *upsert* é a junção de *update* + *insert*: em vez de "insira esta transação", a operação é "se já existe uma transação com esta chave, atualize; se não existe, insira". No Postgres isso é `INSERT ... ON CONFLICT (external_id, provider_account_id) DO UPDATE`, resolvido em um comando só, sem a corrida de consultar antes e inserir depois. Rodar o sync duas vezes não pode duplicar nada.
- Webhooks: guarde `eventId` recebido numa tabela `webhook_event` com unique constraint e ignore reprocessamento.

### 4.4 Fungibilidade e fundos carimbados

**Fungível** é o bem intercambiável por outro igual, sem perda — uma nota de R$ 50 vale qualquer outra nota de R$ 50. Dinheiro é o exemplo canônico. Mas fungibilidade tem duas dimensões: ser intercambiável **e** ser livre de destino. O saldo de vale-refeição/vale-alimentação falha na segunda: a **Lei 14.442/2022** e o **Decreto 12.712/2025** proíbem usar esse saldo para não-alimentício e proíbem o saque, tanto pelo empregador quanto pelo trabalhador. Não é política do emissor (Swile), é lei.

Isso é **dinheiro carimbado**: fungível dentro do próprio pote, infungível entre potes. R$ 100 no Swile valem R$ 100 se e somente se virarem comida.

Decisões que decorrem disso:

- `Account.fundType`: `GENERAL` | `RESTRICTED`. Contas de benefício (Swile) são `RESTRICTED`.
- **O saldo consolidado do dashboard nunca soma fundo `RESTRICTED` com `GENERAL`.** Mostre separado: "R$ 3.200 livres + R$ 480 em alimentação". Somar exibiria uma disponibilidade que eu não tenho.
- O `InternalTransferDetector` (seção 5.1) nunca considera conta `RESTRICTED` como origem ou destino — não existe transferência de lá para lugar nenhum, porque o saque é proibido por lei.
- Orçamento por categoria distingue gasto total de gasto pago com fundo `RESTRICTED`: se tenho R$ 480 de Swile e orcei R$ 900 em alimentação, o que sai do meu bolso é R$ 420.
- A taxa de poupança do snapshot (seção 11.3) exclui saldo `RESTRICTED` — sobra de Swile no fim do mês não é poupança, é saldo preso.
- O `FinancialProfile` (seção 11.2) marca cada fonte de renda também com um **grau de liberdade**, além do grau de garantia: salário é livre, Swile não é.

---

## 5. Os três problemas difíceis (é aqui que apps de finanças costumam errar)

### 5.1 Transferências internas não são gastos

Se eu transfiro R$ 500 do Mercado Pago pro BB, isso aparece como uma saída de R$ 500 e uma entrada de R$ 500. Nenhuma das duas é despesa ou receita — é movimentação interna. Um app ingênuo contabiliza R$ 500 de gasto e destrói o relatório.

Implemente um `InternalTransferDetector` que roda depois de cada sync:
- procura pares de transações em **contas diferentes minhas**, com valores opostos e iguais em módulo, dentro de uma janela de ±3 dias — "conta diferente", não "instituição diferente": o Nubank tem cartão de crédito e NuConta, e uma transferência entre as duas contas do mesmo Nubank é interna do mesmo jeito que uma entre Mercado Pago e BB
- conta com `fundType = RESTRICTED` (seção 4.4) nunca entra como origem ou destino — não existe transferência de saída de um fundo carimbado, o saque é proibido por lei
- se achar, cria um registro `InternalTransfer` ligando as duas e marca ambas com `excludedFromReports = true`
- casos ambíguos (múltiplos candidatos) vão pra fila de revisão manual, não adivinhe

### 5.2 Pagamento de fatura de cartão é dupla contagem

Os gastos do cartão Nubank já entram individualmente como transações do cartão. Quando eu pago a fatura pela conta do Mercado Pago, isso **não é um novo gasto** — é a liquidação dos gastos que já foram contabilizados.

Trate o pagamento de fatura como um caso especial de transferência interna (conta corrente → conta de crédito). Detecte por: conta destino do tipo `CREDIT_CARD` e valor igual ao total da fatura fechada (tabela `statement`, com `closing_date`/`due_date`/`total_amount`). Descrição contendo padrão de pagamento **não** entra na lógica de decisão — descritor de pagamento varia por banco e muda sem aviso, é o tipo de heurística frágil que a seção 8 evita ao preferir *score* a regra binária. Use o padrão de texto só como reforço explicativo na UI ("por que marcamos isso como pagamento de fatura"). Marque `excludedFromReports = true`.

### 5.3 Compras parceladas

Uma compra de R$ 1.200 em 12x aparece como 12 transações de R$ 100 espalhadas por 12 faturas. Preciso ver as duas visões: o impacto no fluxo de caixa mensal (R$ 100/mês) e o gasto real da compra (R$ 1.200 na data da compra).

Modele:
- `Transaction.installmentNumber` (int, nullable), `Transaction.totalInstallments` (int, nullable)
- `Transaction.purchaseGroupId` (UUID, nullable) — agrupa todas as parcelas da mesma compra
- Parser que extrai "3/12", "PARC 03/12", "Parcela 3 de 12" da descrição, com testes cobrindo os formatos de cada instituição
- Relatórios têm um toggle: **regime de caixa** (parcela no mês em que cai) vs **regime de competência** (valor cheio na data da compra)
- Uma tela de "compromissos futuros" mostrando as parcelas já contratadas dos próximos meses — isso é o número que ninguém olha e todo mundo devia

---

## 6. Ingestão bancária (Pluggy)

Já validei o caminho: uso o **Meu Pluggy** (`meu.pluggy.ai`), que é gratuito para uso pessoal. Eu conecto minhas contas lá pela interface deles e pego `clientId`/`clientSecret` + os `itemId` no dashboard. Isso significa que **você não precisa implementar o fluxo de conexão/consentimento nem o Pluggy Connect Widget** — os `itemId` entram como configuração.

O que implementar:

- `PluggyClient`: autenticação (`POST /auth`, que devolve uma `apiKey` temporária), `GET /accounts?itemId=`, `GET /transactions?accountId=&from=&to=` com paginação completa, `PATCH /items/{id}` para forçar atualização.

  Sobre a `apiKey`: ela tem **TTL curto** — *TTL* é *time to live*, o tempo de vida de algo antes de expirar sozinho, e "curto" aqui significa horas, não dias (confirme o valor exato na doc). Isso é proposital: se a chave vazar, ela morre logo. A consequência prática é que o cliente não pode autenticar uma vez e guardar a chave para sempre, nem autenticar a cada requisição (desperdício e risco de rate limit). Guarde a chave em memória com o instante de expiração, reutilize enquanto for válida, e renove automaticamente um pouco **antes** do vencimento — nunca depois de tomar 401, porque aí uma requisição já falhou. Cubra isso com teste: chave válida reutiliza, chave perto de expirar renova.
- `SyncService`: job agendado (`@Scheduled`, a cada 6h, configurável) que para cada item ativo busca contas e transações dos últimos 30 dias e faz upsert. Sincronização inicial busca 12 meses.
- **Webhook** — é a chamada ao contrário. Normalmente o meu sistema chama a API da Pluggy e pergunta "tem novidade?". No webhook, **eu exponho um endpoint e a Pluggy é quem me chama** quando algo acontece. Eu registro uma URL minha no painel deles; quando eles terminam de atualizar uma conta, mandam um `POST` para essa URL com o evento. Em vez de perguntar de 6 em 6 horas e quase sempre ouvir "nada mudou", eu fico sabendo no momento em que muda.

  Implemente `POST /api/webhooks/pluggy` para os eventos de `item/updated`, disparando sync incremental daquele item. Três consequências que decorrem de a chamada vir de fora:

  1. **A URL precisa ser pública** — a Pluggy não alcança `localhost`. Em desenvolvimento, use um túnel (cloudflared ou ngrok) ou simplesmente desligue o webhook e confie no sync agendado. O sistema tem que funcionar sem webhook; ele é otimização, não dependência.
  2. **Qualquer um pode mandar um POST para esse endereço.** Valide a assinatura/origem antes de processar qualquer coisa, e trate o corpo como dado não confiável. Confirme na doc da Pluggy como eles assinam.
  3. **A entrega pode repetir.** Retry deles, rede instável, timeout do meu lado — o mesmo evento chega duas vezes. Por isso a tabela `webhook_event` com unique constraint da seção 4.3: registrou, ignora a repetição.
- **Resiliência.** Chamada de rede falha, e a diferença entre um sistema que se recupera e um que piora a situação está aqui:

  - **Retry** — se a chamada falhou por algo passageiro (timeout, 503, rede oscilando), tente de novo em vez de desistir na primeira.
  - **Backoff exponencial** — mas não tente de novo imediatamente, nem em intervalo fixo. Espere um tempo que **dobra a cada tentativa**: 1s, 2s, 4s, 8s, com um teto. O motivo: se a API caiu, mil retries a cada segundo atrasam a recuperação dela e podem te render um bloqueio por abuso. Backoff dá tempo do outro lado se levantar. Some **jitter** (uma variação aleatória pequena no intervalo) para que várias contas minhas falhando juntas não voltem a bater todas no mesmo instante.
  - **Circuit breaker** — o disjuntor. Se as falhas se acumulam além de um limite, ele "abre" e passa a rejeitar as chamadas **na hora, sem nem tentar a rede**, por um período. Depois deixa passar uma de teste: se funcionou, fecha e volta ao normal. Sem isso, cada requisição fica esperando timeout e o sistema trava inteiro por causa de um serviço externo morto — falhar rápido é melhor que travar devagar.
  - **Retry só para erro transitório.** Credencial inválida, MFA expirado ou 401 não melhoram com repetição: retentar é só desperdício. Classifique o erro antes de decidir.

  Persista também um `SyncLog` com status, duração, quantidade de transações novas e erro. Uma conta que falha não pode derrubar o sync das outras.
- Falha de credencial (`LOGIN_ERROR`, MFA expirado) não é retry — é notificação pra mim resolver.

**Swile:** não confirmei se existe conector. Na fase de integração, chame `GET /connectors` e me diga o que existe para Swile e benefícios em geral. Se não houver, implemente o fallback (seção 6.1) e siga em frente — não trave o projeto nisso.

### 6.1 Fallback obrigatório: importação manual

Independente do Pluggy funcionar para tudo, implemente entradas manuais que passam pelo **mesmo pipeline** de deduplicação, categorização e conciliação das transações automáticas. Nunca crie um caminho paralelo que escape das regras da seção 5.

**a) Arquivo** — importador de OFX, CSV e QIF, com mapeamento de colunas configurável e salvo por instituição (configurei uma vez, o próximo arquivo daquele banco já vem mapeado).

**b) Print de celular** — quero fotografar ou printar a tela do extrato/fatura do app do banco e ter as transações registradas. É o meu plano B para Swile e para qualquer conector que quebre. Funcionamento:

- Envio uma ou várias imagens de uma vez. Extração por visão (mesma infra da seção 7.2), retornando uma **lista** de transações, não uma só: `[{ date, description, amount, direction }]`.
- Peça o contexto que a imagem não tem: de qual conta é, e qual o ano (print de app quase sempre mostra só "12 mar").
- **Tela de revisão obrigatória antes de persistir.** Isso é extração de imagem, não dado oficial — mostre as linhas extraídas em uma tabela editável, com o print ao lado, e só grave depois que eu confirmar. Nada de print entra no banco direto.
- Marque essas transações com `source = SCREENSHOT` e trate-as como **menos confiáveis que as do Pluggy**.

**O problema difícil aqui é duplicata cruzada.** Uma transação que eu importei por print hoje pode chegar pelo Pluggy amanhã, com id externo, descrição diferente e a mesma essência. Sem tratamento, meu extrato ganha lançamentos fantasma e todo relatório mente.

Implemente `ManualEntryDeduplicator`, reaproveitando a lógica de pontuação da seção 8 (valor, proximidade de data, similaridade de descrição). Quando uma transação do Pluggy casar com uma de `source = SCREENSHOT` ou `source = FILE`: **a versão do provedor vence**, herda a categoria e os vínculos de nota fiscal que eu já tinha feito na manual, e a manual é marcada como `supersededBy` apontando para ela — não apagada, para eu poder auditar. Casos ambíguos vão para a fila de revisão, nunca para o descarte automático.

Cubra isso com teste explícito: importo um print, o Pluggy traz a mesma transação depois, e o total do mês não muda.

---

## 7. Notas fiscais — a feature principal

### 7.1 Caminho primário: QR code da NFC-e (não OCR)

Todo cupom fiscal brasileiro (NFC-e) tem um QR code que aponta para o portal da SEFAZ do estado, com a chave de acesso de 44 dígitos e um hash de validação. Essa página traz os **dados estruturados e oficiais** da compra: cada item, quantidade, unidade, valor unitário, valor total, CNPJ e razão social do emitente, data/hora, forma de pagamento.

Isso é infinitamente mais confiável que OCR. **Priorize esse caminho.**

Implemente:
- `NfceQrParser`: recebe a URL do QR, extrai chave de acesso, UF (posições 0-1 da chave), versão, ambiente e hash.
- Porta `NfceProvider` com implementações por UF. Comece por **MA** (moro em São Luís) e **SP**. Cada implementação busca a página de consulta e faz parse do HTML (use Jsoup) para o modelo de domínio.
- O parse de HTML é frágil por natureza: isole cada UF em sua classe, cubra com testes usando HTML fixado em `src/test/resources`, e falhe de forma explícita (nunca salve dados parciais silenciosamente).
- UF não implementada → salva a nota como `PENDING_MANUAL` com a chave de acesso e a imagem, e cai no caminho secundário.

### 7.2 Caminho secundário: extração por visão

Para comprovantes sem QR (recibo de restaurante, print de pedido de delivery, comprovante de Pix, fatura de serviço), envie a imagem para a API da Anthropic com um prompt que retorna **JSON estrito**:

```
{ "merchant": string, "cnpj": string|null, "date": "YYYY-MM-DD", "total": number,
  "paymentMethod": string|null,
  "items": [{ "description": string, "quantity": number, "unitPrice": number, "totalPrice": number }] }
```

Regras:
- Valide o JSON com um schema antes de persistir. Nunca confie na saída direto.
- Valide a aritmética: se `sum(items.totalPrice)` divergir de `total` em mais de R$ 0,05, marque `needsReview = true` e mostre isso na UI.
- Modelo configurável por properties, chave via variável de ambiente.
- Guarde a imagem original (filesystem local, path no banco) — sempre preciso poder auditar.

### 7.3 Captura no celular (o "menor trabalho possível")

Uma rota `/capturar` no frontend, otimizada para mobile e instalável como PWA:
- Abre a câmera direto, sem cliques intermediários
- Lê o QR code no cliente com `html5-qrcode` — se ler, envia só a URL (rápido, sem upload de imagem)
- Se não ler QR em ~5 segundos, oferece "tirar foto" e envia a imagem para o caminho de visão
- Feedback imediato: "Nota registrada — R$ 87,40 no Supermercado X, 14 itens" e volta pra câmera
- **Funciona offline.** Sinal ruim dentro de supermercado é regra, não exceção, e a captura não pode se perder por causa disso. Enfileire localmente e sincronize quando a conexão voltar, com indicação visível de quantos itens estão pendentes.

  Use **IndexedDB** para essa fila: é um banco de dados que roda dentro do navegador, no próprio aparelho, e sobrevive a fechar o app e reiniciar o celular. Diferente do `localStorage`, que só guarda texto, é pequeno e é síncrono (trava a interface), o IndexedDB guarda objetos estruturados e arquivos binários — que é o que eu preciso, já que a fila pode conter a **foto** da nota, não só a URL do QR. Não escreva a API dele na mão, que é verbosa; use uma biblioteca fina por cima (ex: `idb`) e me explique o que ela está encapsulando.

O fluxo inteiro tem que ser: abrir app → apontar → pronto. Menos de 5 segundos.

---

## 8. Conciliação nota fiscal ↔ transação bancária

Esse é o coração do sistema. Uma nota fiscal e a transação do cartão são registros independentes que precisam ser casados.

Implemente `ReconciliationService` com scoring, não com regra binária:

**Candidatos:** transações não conciliadas, mesma direção (despesa), dentro de ±5 dias da data da nota.

**Score (0.0 a 1.0), soma ponderada:**

| Critério | Peso | Pontuação |
|---|---|---|
| Valor | 0.50 | exato = 1.0; diferença ≤ 2% ou ≤ R$ 0,50 = 0.7; senão 0 |
| Data | 0.25 | mesmo dia = 1.0; ±1 dia = 0.85; ±3 dias = 0.6; ±5 dias = 0.3 |
| Estabelecimento | 0.25 | similaridade Jaro-Winkler entre razão social/nome fantasia normalizado e o descritor da transação |

Normalização do estabelecimento antes de comparar: maiúsculas, sem acentos, remover sufixos societários (LTDA, ME, EIRELI, S/A), remover prefixos de adquirente que sujam o descritor do cartão (`PAG*`, `MP*`, `IFD*`, `PICPAY*`, `EC *`, `CIELO*`), colapsar espaços.

**Decisão:**
- score ≥ 0.85 **e** o segundo melhor candidato < 0.60 → vincula automaticamente
- 0.60 ≤ score < 0.85, ou empate técnico → fila de revisão na UI, com os candidatos ordenados e o score visível
- score < 0.60 → nota fica órfã (ainda válida e visível; pode ser compra em dinheiro)

**Aprendizado:** quando eu confirmo ou corrijo um vínculo manualmente, persista o mapeamento `CNPJ → descritor de transação` numa tabela `merchant_alias`. Nas próximas vezes, um alias conhecido vale score 1.0 no critério de estabelecimento. O sistema tem que ficar melhor com o uso.

**Modelo:** o vínculo é uma entidade própria (`ReceiptTransactionLink`) com `confidence`, `matchedAutomatically`, `confirmedByUser`, `createdAt`. Relação N:N — uma nota pode ser paga com dois cartões, uma transação pode cobrir duas notas.

---

## 9. Categorização automática

Três camadas, nessa ordem de precedência:

1. **Regras do usuário** (maior precedência): condições sobre descritor, CNPJ, valor, conta. Criadas por mim na UI ou automaticamente quando eu recategorizo algo ("sempre categorizar assim?").
2. **Regras base** (seed): um conjunto pré-carregado por Flyway com os merchants brasileiros comuns — iFood, Rappi, Uber, 99, Amazon, Mercado Livre, Netflix, Spotify, postos, farmácias, supermercados. Case-insensitive, por substring e por CNPJ.
3. **LLM** (último recurso): se nada casou, classifica via API com a lista de categorias disponíveis. Persiste a sugestão com `confidence` e `source = AI`. Sugestões de IA de baixa confiança aparecem destacadas para revisão. **Cacheie por descritor normalizado** — não chame a API duas vezes pro mesmo merchant.

Categorias: hierárquicas em dois níveis (Alimentação → Supermercado / Restaurante / Delivery). Seed com um conjunto sensato brasileiro, mas totalmente editável — cor, ícone e orçamento por categoria.

**Categorização em nível de item:** quando a nota fiscal está vinculada, cada item também é categorizado. Uma compra no supermercado de R$ 300 pode ser 60% alimentação, 25% limpeza, 15% higiene. Essa granularidade é o diferencial do sistema — os relatórios precisam expor isso.

---

## 10. Frontend

### 10.1 Design

Dark mode como padrão (com toggle para claro). Quero algo que pareça uma ferramenta financeira séria, não um dashboard de template.

- **Nunca use preto puro.** Fundo base `#0A0A0C`, superfícies elevadas `#141417`, bordas `rgba(255,255,255,0.08)`.
- Hierarquia por elevação e espaçamento, não por bordas grossas.
- Uma cor de acento só (sugestão: um verde-esmeralda ou âmbar dessaturado). Vermelho e verde reservados exclusivamente para semântica de valor (despesa/receita) — não use essas cores para nada decorativo.
- Números são o conteúdo principal: fonte com **tabular numerals** (`font-variant-numeric: tabular-nums`) em toda coluna de valor, para os dígitos alinharem. Considere Geist Mono ou JetBrains Mono nos valores.
- Densidade de informação alta. Não desperdice a tela com cards gigantes de um número só.
- Estados vazios, de carregamento e de erro em todas as telas. Skeleton, não spinner.
- **Identidade.** O ícone e a marca saem do próprio nome: o glifo do cifrano (o símbolo monetário de duas barras verticais) é a base do logo. Um traço só, geométrico, legível a 32px — nada de mascote, gradiente ou sombra. As duas barras verticais dão um paralelo natural com a régua/eixo de um gráfico; explore isso se render, mas não force. No cabeçalho, "Cifrano" em peso médio, sem slogan.

### 10.2 Telas

**Dashboard** — saldo consolidado com fundos livres e carimbados separados (seção 4.4: "R$ 3.200 livres + R$ 480 em alimentação", nunca somados), gasto do mês vs mês anterior, projeção de fim de mês, fatura atual do cartão, alertas de orçamento estourado.

**Transações** — filtro por período/conta/categoria/valor, busca full-text, edição inline de categoria, ações em lote, indicador de nota fiscal vinculada.

Sobre o volume: em um ano eu vou ter alguns milhares de transações, e uma tabela HTML com milhares de linhas trava o celular — o navegador cria um elemento para cada linha e cada rolagem obriga ele a recalcular tudo. Duas defesas, nessa ordem:

1. **Paginação no servidor** — não traga 5.000 linhas para a tela em nenhuma hipótese. Resolve a maior parte do problema sozinho.
2. **Tabela virtualizada** — se ainda assim a lista longa travar, virtualize. *Virtualizar* é renderizar só as linhas visíveis: se cabem 20 na tela, existem ~25 elementos no DOM, e ao rolar a biblioteca reaproveita esses mesmos elementos trocando o conteúdo, mantendo a altura total simulada para a barra de rolagem parecer normal. A lista pode ter 10.000 itens que o custo de renderização não muda.

Siga a regra da seção 10.4 aqui: **construa sem virtualização primeiro**, gere alguns milhares de transações de teste, sinta a lentidão no celular, e só então introduza a virtualização em um commit separado explicando o que mudou. É o melhor exemplo do projeto inteiro para entender o que o React faz com o DOM.

**Detalhe da transação** — dados bancários, nota fiscal vinculada com todos os itens, botão para vincular manualmente.

**Notas fiscais** — grid com as notas, fila de conciliação pendente em destaque, drill-down até o item.

**Relatórios** — aqui moram os gráficos. Anotei o que cada um é e, mais importante, **que pergunta ele responde** — se um gráfico não responde a uma pergunta que eu realmente faço, ele não deveria existir:

- **Donut** de gastos por categoria, com drill-down para subcategoria e daí para itens. *"Para onde foi meu dinheiro este mês?"* Rosca é pizza com o meio vazio; serve para composição de um total.
- **Área empilhada** de evolução mensal por categoria, 12 meses. Linhas empilhadas uma sobre a outra, onde a espessura de cada faixa é o valor daquela categoria. *"O que mudou no meu padrão de gasto ao longo do ano?"*
- **Barras comparativas** mês a mês, com variação percentual. *"Gastei mais ou menos que no mês passado?"*
- **Treemap** de estabelecimentos. Retângulos aninhados preenchendo a tela, onde a **área de cada um é proporcional ao valor gasto** — quanto maior o retângulo, maior o gasto naquele estabelecimento. *"Quais lugares consomem meu dinheiro?"* A vantagem sobre o donut é caber dezenas de itens legíveis na mesma tela; a fraqueza é que o olho compara área mal, então não use quando a diferença entre os valores for pequena.
- **Heatmap de calendário**: os dias do ano em grade, cada dia colorido pela intensidade do gasto. *"Em que dias eu gasto? Fim de semana? Sempre depois do pagamento?"*
- **Waterfall** (cascata) de fluxo de caixa mensal: barras que partem do saldo inicial, sobem com as entradas, descem com cada categoria de saída e terminam no saldo final. *"Como eu saí de X e cheguei em Y?"* É o gráfico que mostra o caminho, não só o começo e o fim.
- **Inflação pessoal**: preço médio de um mesmo item ao longo do tempo, extraído das notas fiscais. Ex: quanto o quilo do café que eu compro subiu em 12 meses. Ninguém tem isso e os dados já estão lá.
- **Linha de compromissos futuros**: parcelas já contratadas dos próximos 12 meses. *"Quanto do meu salário futuro já está comprometido?"*

Se algum desses ficar ruim com os meus dados reais — poucas categorias, valores muito desiguais, meses vazios —, me diga e proponha outro. Gráfico bonito com dado que não sustenta ele é pior que tabela.

**Orçamentos** — limite por categoria, progresso do mês, projeção de estouro baseada no ritmo atual.

**Contas** — status de cada conexão, último sync, saldo, botão de sync manual.

**Capturar** — a rota mobile da seção 7.3.

### 10.3 Regras técnicas
- Server Components por padrão; `"use client"` só onde há interatividade real.
- **TanStack Query para todo estado de servidor.** Existem dois tipos de estado numa tela, e confundi-los é o erro mais comum de quem está começando:
  - **Estado de cliente** — nasce e morre no navegador: o modal está aberto? o que eu digitei no campo de busca? qual aba está selecionada? A fonte da verdade é a própria tela, e `useState` resolve.
  - **Estado de servidor** — a lista de transações, o total do mês, as categorias. A fonte da verdade é o **banco de dados**; o que está na tela é apenas uma **cópia**, que pode ficar desatualizada a qualquer momento. Não é estado, é cache — e tratar cache como se fosse estado local é a origem de metade dos bugs de tela desatualizada.

  O TanStack Query cuida dessa cópia: guarda o resultado, sabe quando ele envelheceu, refaz a busca sozinho, entrega os estados de carregando/erro prontos e evita que dois componentes pedindo o mesmo dado disparem duas requisições.

- **Invalidação correta após mutações.** *Mutação* é toda operação que altera dado no servidor (criar, editar, apagar). Depois dela, todas as cópias em cache que dependiam daquele dado estão erradas — *invalidar* é marcar essas cópias como vencidas para que sejam buscadas de novo.

  O caso concreto que eu quero ver funcionando: eu recategorizo uma transação na tela de transações. Isso muda o total da categoria no dashboard, muda o donut, muda o progresso do orçamento e muda o relatório do mês. Se a mutação invalidar só a lista de transações, todo o resto continua mostrando número errado até eu recarregar a página — e eu vou acreditar no número errado, porque não tenho como saber que ele é velho. Mapeie, para cada mutação, **todas** as consultas afetadas, e me explique esse mapeamento por escrito antes de implementar.
- Todos os DTOs validados com zod na fronteira. Gere os tipos a partir do OpenAPI do backend (`openapi-typescript`) — não escreva tipos à mão que vão dessincronizar.
- Formatação de moeda e data centralizada em `lib/format.ts`, locale `pt-BR`. Nunca formate inline.

### 10.4 Como me ensinar frontend

Trate esta fase como se eu nunca tivesse escrito React. Ela exige muito mais didática que as outras, e é melhor entregar três telas que eu entendo do que dez que eu não entendo.

**Antes de qualquer código de tela, escreva `docs/aprendizado/react-do-zero.md`.** Uma página por conceito, nessa ordem exata, cada uma com um exemplo mínimo tirado deste projeto e não um `<Counter />` genérico:

1. **Componente** — uma função que devolve marcação. Por que função e não template.
2. **Props** — os argumentos que a função recebe. Por que fluem só de cima para baixo, e por que o filho não pode alterá-las.
3. **Estado (`useState`)** — o que é, por que uma variável comum não serve, o que exatamente acontece quando você chama o setter, e por que o valor não muda na linha seguinte.
4. **Renderização** — quando o React reexecuta a função do componente e o que ele faz com o resultado.
5. **Listas e `key`** — porque a primeira tela do projeto é uma lista de transações.
6. **Server vs Client Component** — só depois que os cinco acima estiverem firmes.

Pare depois desse documento e me deixe ler antes de continuar.

Depois disso, durante a implementação:

- **Um conceito novo por commit, no começo.** Nos primeiros commits da fase 5, não empilhe hooks, biblioteca de dados e estilização no mesmo diff. Introduza um conceito, mostre funcionando, explique, siga.
- **Toda vez que um `"use client"` aparecer, justifique.** Qual interatividade específica obrigou aquele componente a virar cliente, e por que o pai continua no servidor. É o conceito central do App Router e o que mais gente usa errado.
- **Explique cada hook na primeira vez que ele aparecer:** o que resolve, quando *não* usar, e o erro clássico associado. Especialmente `useEffect` — quero entender por que a maior parte dos `useEffect` que se vê por aí não deveria existir.
- **Justifique cada peça do TanStack Query** quando entrar: por que não basta `useState` + `fetch`, o que são cache, `staleTime`, invalidação e refetch, e o que aconteceria sem a biblioteca. Faça o mesmo com o zod: me mostre na prática um dado do backend chegando fora do formato esperado e o que acontece com e sem validação.
- **Construa a tela de transações do jeito ingênuo primeiro, depois refatore.** Quero o commit com a versão simples e o commit seguinte com a versão correta, cada um explicando o que quebrou ou o que melhorou. Uma tela nesse formato vale mais que dez prontas.
- **Não use bibliotecas que escondam o conceito.** Se um componente shadcn/ui esconde algo que eu precisaria entender, explique o que ele faz por baixo antes de usá-lo. Se um componente meu está fazendo algo que dá para escrever à mão em dez linhas e essas dez linhas ensinam alguma coisa, escreva à mão primeiro.
- **Ordem de entrega:** tela de transações (lista, fetch, filtro, mutação — cobre a maior parte do que existe em React), depois dashboard e gráficos, depois o resto. Não comece pelo mais bonito.
- **Ao final da fase, me proponha três exercícios pequenos** para eu fazer sozinho no próprio projeto: uma feature simples de UI que eu implemento sem você, com o resultado esperado descrito mas sem o código. Aprender React lendo código pronto não funciona.

---

## 11. Assistente financeiro (IA)

Quero que o sistema use os meus próprios dados para me dar sugestões: cortes, substituições, ajustes de orçamento, padrões de hábito, e simulações. Não é chatbot genérico de finanças — é análise em cima do meu extrato real e das minhas notas fiscais.

### 11.1 A regra de ouro: o LLM não calcula

**Todo número vem do backend, calculado em SQL. O LLM só interpreta.**

Modelos de linguagem produzem aritmética que *parece* certa e frequentemente não é. Num app de finanças, um número errado é pior que nenhuma resposta, porque eu vou acreditar nele e decidir em cima dele.

Portanto:
- O backend calcula todos os agregados de forma determinística e monta um **snapshot** (seção 11.3).
- O LLM recebe o snapshot pronto e produz interpretação, comparação e sugestão — nunca soma, média ou projeção.
- Instrua o modelo a **só usar números presentes no snapshot** e a citar o campo de onde tirou cada um.
- **Valide a saída:** extraia os números da resposta e confira se cada um existe no snapshot. Se aparecer um número inventado, descarte a resposta e registre o caso. Cubra isso com teste.

Se você se pegar escrevendo um prompt que pede "calcule quanto ele gastaria se...", pare: essa conta é do backend, e o LLM só narra o resultado.

### 11.2 Contexto que eu forneço: `FinancialProfile`

O extrato sozinho não sabe quem eu sou. Crie uma entidade editável pela UI com:

- **Fontes de renda**, cada uma com valor, recorrência, **grau de garantia** e **grau de liberdade**: salário CLT (fixo, livre), freelas (variável, informo faixa, livre), **ajuda de custo dos meus pais** (recorrente mas não garantida, livre), saldo de benefício tipo Swile (garantido pelo empregador, mas **carimbado** — só vira alimentação, ver seção 4.4). Sem o grau de liberdade, a IA sugere coisas impossíveis, tipo cortar o orçamento de alimentação para engordar a reserva de emergência com um dinheiro que juridicamente não pode sair do pote de comida.
- **Compromissos fixos** que eu conheço e ainda não aparecem no extrato (aluguel que vai subir, curso que começa em março).
- **Metas**: reserva de emergência, objetivo de compra, valor e prazo.
- **Restrições e preferências**: o que eu não abro mão. Se eu marcar que café especial é inegociável, não quero ver sugestão de cortar café todo mês.
- **Notas livres**: campo de texto onde eu escrevo contexto que não cabe em campo estruturado ("minha esposa está na faculdade de medicina, a renda dela é zero até 2028").

O perfil entra no snapshot. Sem ele, a IA vai sugerir coisas que ignoram metade da minha vida.

### 11.3 O snapshot

Um único objeto, calculado no backend, com tudo que a análise precisa — **agregados, nunca o dump de transações**. Mais barato, mais privado, e gera resposta melhor que jogar 5.000 linhas no contexto.

Deve conter: totais e mediana por categoria nos últimos 3, 6 e 12 meses; variação mês a mês; **recorrências detectadas** (mesmo valor, mesmo estabelecimento, mesma janela do mês — as assinaturas); maiores estabelecimentos; orçamento previsto vs realizado; parcelas já contratadas dos próximos 12 meses; renda por fonte; taxa de poupança; e, vindo das notas fiscais, os itens mais comprados com preço médio e onde foram comprados.

Versione o formato do snapshot e guarde cada um gerado. Quero poder reler uma sugestão de seis meses atrás e saber exatamente sobre quais dados ela foi feita.

### 11.4 O que eu quero que ele encontre

- **Assinaturas e recorrências** que eu esqueci que existem.
- **Substituições concretas**, usando os dados de item das notas fiscais: o mesmo produto que eu compro custa menos em outro estabelecimento onde eu já compro. Isso só é possível porque tenho preço por item — é a análise mais valiosa do sistema e nenhum app de banco faz.
- **Cortes com impacto estimado**, sempre com o número calculado pelo backend.
- **Orçamento sugerido a partir do meu histórico real**, não de regra genérica tipo 50/30/20. Se a minha mediana de alimentação é R$ 900, propor R$ 500 é fantasia.
- **Padrões de hábito**: dia da semana, horário, proximidade do pagamento, gasto por impulso após determinado gatilho.
- **Cenários**, calculados pelo backend e narrados pela IA: e se a ajuda dos meus pais acabar? e se eu cortar as três maiores assinaturas? quanto tempo até a reserva de emergência no ritmo atual?
- **Alerta de ritmo**: no dia 12 já gastei o que costumo gastar até o dia 20.

### 11.5 Como ele deve falar comigo

- **Observação + número + pergunta, nunca sermão.** "Delivery foi R$ 620 em julho, contra mediana de R$ 380 nos seis meses anteriores. Foi algo pontual?" — e não "você está gastando demais com delivery".
- **Nem todo gasto alto é problema.** Gasto pode ser escolha deliberada. Pergunte antes de assumir que eu quero cortar.
- **Separe explicitamente três coisas:** o que é fato tirado do dado, o que é inferência, e o que é sugestão. Não misture os três na mesma frase.
- **Diga quando não sabe.** Com menos de três meses de histórico, quase nenhuma comparação se sustenta — nesse caso diga isso em vez de inventar tendência.
- **Nada de conselho genérico.** "Monte uma reserva de emergência" é frase de revista. Só quero o que decorre dos meus dados.
- **Sem culpa, sem emoji comemorativo, sem gamificação.** App de finanças que dá sermão é app que eu paro de abrir.
- **Limite de escopo:** o sistema analisa os meus gastos. Ele **não** recomenda investimento, produto financeiro, ou decisão de crédito e dívida — para isso existe profissional habilitado, e o modelo não tem como saber o suficiente. Se eu perguntar, ele aponta o que os meus dados mostram e deixa a decisão comigo.

### 11.6 Interface

- **Revisão mensal**: gerada uma vez por mês, quando o mês fecha. É o produto principal, não o chat.
- **Sugestões como cards acionáveis**, não parágrafos soltos: cada uma com aceitar/dispensar. Aceitar uma sugestão de orçamento **cria o orçamento**; aceitar uma de categorização **cria a regra**. Sugestão que não vira ação é texto bonito.
- **Dispensar alimenta o sistema**: guarde o motivo e não repita a mesma sugestão no mês seguinte.
- **Chat livre** sobre o snapshot, para eu perguntar o que quiser em linguagem natural. Ele responde a partir do snapshot; se a pergunta exigir um cálculo que não está lá, o backend calcula primeiro e só então o modelo narra.

### 11.7 Custo e privacidade

- Porta `AdviceProvider` no domínio, para eu poder trocar o modelo — inclusive por um modelo local (Ollama) no futuro, se eu decidir que não quero mais meus dados saindo da VPS.
- A revisão mensal roda **uma vez por mês**, não a cada carregamento de tela. Cacheie por versão de snapshot.
- **Deixe explícito na UI quais dados são enviados** para a API externa antes do primeiro envio, e me peça confirmação. São os meus gastos inteiros; eu quero saber, não descobrir depois.
- Nunca envie número de conta, número de documento, chave Pix ou chave de acesso de NFC-e. Nome de estabelecimento e valores agregados bastam para a análise.

---

## 12. Testes — e como me ensinar a escrever bons testes

Quero sair deste projeto sabendo testar de verdade, não decorando anotações. E aqui isso não é só aprendizado: num sistema financeiro, o bug típico não derruba nada — ele produz um número errado que eu vou olhar, acreditar e usar para decidir. Teste é a única defesa contra isso.

Vale o mesmo espírito das seções 3.1 e 10.4: explique o **porquê** de cada escolha no momento em que ela aparece.

### 12.1 Quando usar cada tipo

A regra geral: **muitos testes rápidos e poucos lentos.** Teste lento demais deixa de ser rodado, e teste que não roda não protege nada.

- **Unitário** — domínio puro, sem Spring, sem banco, sem rede. Milissegundos. Se o teste precisa subir o Spring, ele não é unitário. É aqui que mora a maior parte do valor neste projeto: `Money`, o cálculo de score da seção 8, o parser de parcelamento, a normalização de nome de estabelecimento, o `InternalTransferDetector`, o `NfceQrParser`. **A arquitetura hexagonal da seção 3 existe em boa parte para isto** — o domínio não depende de framework, então testá-lo é instanciar a classe e chamar o método. Aponte essa conexão quando escrever o primeiro deles.
- **Teste de repositório** (`@DataJpaTest` + Testcontainers) — Postgres real em Docker. Explique **por que não H2**: o banco em memória mente. Ele não tem o `ON CONFLICT` que a seção 4.3 depende, trata `NUMERIC` e fuso de forma diferente, e aceita SQL que o Postgres recusa. Teste que passa contra um banco que não é o seu é falsa sensação de segurança.
- **Teste de camada web** (`@WebMvcTest`) — controller isolado: serialização JSON, validação de entrada, códigos de status. Sem banco, sem contexto inteiro.
- **Teste de integração completo** (`@SpringBootTest`) — poucos, para verificar que a fiação toda funciona: contexto sobe, migrations rodam, configuração carrega. Explique o custo de subir o contexto e por que usar fatia sempre que der.
- **Teste contra API externa** (WireMock) — **nunca chame a Pluggy de verdade num teste.** Teste que depende de rede é lento, falha sem motivo e depende de dado que muda sozinho.

  **WireMock** é um servidor HTTP falso que sobe dentro do próprio teste, numa porta local. Eu digo a ele "quando chegar `GET /transactions`, responda isto"; aponto o `PluggyClient` para `localhost` em vez de `api.pluggy.ai`; e o cliente faz uma requisição HTTP de verdade, só que para um servidor que eu controlo. A diferença para simplesmente mockar a classe do cliente é grande: com WireMock, a serialização, os headers, o parse do JSON, o retry e o timeout são exercitados de verdade — mockando a classe, esse caminho todo fica sem teste.

  **Fixture** é dado de teste fixo, preparado de antemão e guardado num arquivo (aqui, em `src/test/resources`). Em vez de inventar um JSON à mão, capture uma resposta real da Pluggy, **substitua os meus dados** (valores, nomes, ids) e salve como fixture. Assim o teste roda contra o formato que a API realmente devolve, incluindo os campos estranhos que ninguém colocaria num exemplo inventado. Quando a Pluggy mudar o contrato, atualizar a fixture mostra exatamente o que mudou.

  Teste explicitamente os caminhos ruins, que são os que quebram em produção e os que o WireMock torna fáceis de simular: paginação com várias páginas, HTTP 500, timeout, chave expirada no meio do sync, JSON com campo faltando, valor com sinal invertido.
- **Teste de migration** — o Flyway roda limpo num banco vazio, e uma migration nova não quebra dados que já existem.
- **ArchUnit** — teste de arquitetura, não de comportamento: falha o build se `domain` importar Spring ou JPA.
- **Frontend** — Vitest + Testing Library para componentes, e Playwright só para o fluxo crítico ponta a ponta (capturar nota → conciliar → aparecer na tela). Explique a filosofia da Testing Library: testar o que o usuário vê e faz, não o estado interno do componente.
- **Property-based testing** (jqwik) — só depois que o resto estiver de pé, e como conceito avançado. Em vez de escrever exemplos, eu declaro invariantes e a biblioteca gera centenas de casos tentando quebrá-las. Perfeito para o `Money` (`a + b - b == a` para qualquer a e b) e para o scorer (`score` sempre entre 0 e 1, qualquer que seja a entrada). Mostre uma vez, no `Money`, e me deixe ver a biblioteca achar um caso de borda que eu não teria imaginado.

### 12.2 O que faz um teste ser bom

- **Testa comportamento, não implementação.** Se eu refatorar por dentro sem mudar o que a classe faz, o teste tem que continuar passando. Teste que quebra a cada refactor vira peso morto e acaba deletado.
- **Um comportamento por teste**, com Arrange/Act/Assert visível. Teste que verifica cinco coisas não diz qual delas quebrou.
- **Não mocke o que você não controla.** Mocke a porta (`BankDataProvider`), nunca o cliente HTTP ou o `RestClient` da biblioteca. Explique por que mockar biblioteca de terceiro produz teste que passa com código quebrado.
- **Determinismo absoluto.** Nada de relógio real, aleatoriedade, rede ou `Thread.sleep`. **Injete `Clock`** em tudo que usa data — este projeto está cheio de janela de ±3 dias e fechamento mensal, e sem `Clock` injetável eu vou ter teste que só falha no dia 31 ou na virada do mês. Esse é o conceito mais importante desta seção inteira; demonstre no `InternalTransferDetector`.
- **Builders de dados de teste** em vez de setup copiado. Uma `TransactionBuilder` com valores padrão sensatos, onde cada teste sobrescreve só o campo que importa para ele — assim o teste mostra o que é relevante.
- **Asserção que significa alguma coisa.** `assertNotNull` quase nunca é o que você queria verificar.
- **Cobertura é sintoma, não meta.** Não persiga porcentagem. Prefira cobrir bem os quatro pontos onde um erro me custa dinheiro: `Money`, deduplicação, transferência interna e conciliação.

### 12.3 Como quero aprender

- **Faça o ciclo test-first pelo menos uma vez, explicitamente**, no scorer da seção 8: transforme cada linha da tabela de pesos em um teste que falha, e só então implemente até todos passarem. Quero ver que a tabela de regras vira suíte de teste quase mecanicamente.
- **Mostre pelo menos um teste ruim e por que é ruim** — o clássico que só verifica que um mock foi chamado, ou o que depende de `LocalDate.now()` e quebra na virada do mês. Ver o teste ruim ensina mais que a regra abstrata.
- **A cada fase, diga qual tipo de teste você escolheu e por quê.** Se optar por `@SpringBootTest` onde caberia `@DataJpaTest`, justifique.
- **Uma vez, ao final da fase 4, rode teste de mutação** (PIT) na área de conciliação. Ele altera o código de propósito e vê se algum teste percebe. É a demonstração mais direta de que cobertura alta não significa teste bom — e é o tipo de coisa que eu não descobriria sozinho.

---

## 13. Segurança

São dados financeiros reais numa VPS exposta à internet. Não relaxe nisso por ser single-user.

- **Autenticação: usuário único.** São quatro peças, e cada uma resolve um ataque diferente:

  - **Senha com BCrypt** — nunca guarde a senha, guarde um *hash* dela: um resultado de mão única, do qual não dá para voltar à senha original. O BCrypt tem duas propriedades que um hash comum (SHA-256, por exemplo) não tem: é **propositalmente lento**, com custo configurável, o que inviabiliza testar bilhões de senhas por segundo; e embute um **salt** aleatório por senha, de modo que duas senhas iguais geram hashes diferentes e tabelas prontas de hash não servem para nada. No login você não descriptografa nada — você aplica o mesmo processo à senha digitada e compara os hashes.
  - **JWT** (*JSON Web Token*) — o crachá que o servidor emite depois do login. É um texto com alguns dados (quem sou eu, quando expira) mais uma **assinatura** feita com uma chave secreta do servidor. Nas requisições seguintes, o servidor confere a assinatura e sabe que o token foi emitido por ele e não foi adulterado, sem precisar guardar sessão. **Atenção: JWT não é criptografado** — qualquer um que o tenha consegue ler o conteúdo. A assinatura garante integridade, não sigilo. Nunca coloque nada sensível dentro dele.
  - **Cookie `httpOnly`** — onde o token fica guardado no navegador. `httpOnly` significa que o **JavaScript da página não consegue ler esse cookie**; só o navegador o manipula, enviando-o automaticamente nas requisições. É a defesa contra XSS: se algum script malicioso entrar na página, ele não consegue roubar o token. Guardar JWT em `localStorage` é o erro comum aqui, porque lá o JavaScript lê à vontade. Marque também como `Secure`, para só trafegar em HTTPS.
  - **`SameSite=Strict`** — instrui o navegador a só enviar esse cookie quando a requisição parte do próprio site. Sem isso, um site qualquer que eu abra numa outra aba pode disparar uma requisição para o meu sistema, e o navegador anexaria o cookie automaticamente — é o ataque CSRF. Com `Strict`, o cookie simplesmente não vai junto.

  E **sem "lembrar de mim" eterno**: token de vida curta, renovação enquanto eu estiver usando. Token que nunca expira é senha permanente escrita num arquivo.
- Segredos só via variáveis de ambiente. `.env` no `.gitignore` desde o primeiro commit. Commit um `.env.example`.
- Rate limiting nos endpoints de autenticação e de upload.
- Caddy na frente com TLS automático. Postgres nunca exposto pra fora do compose.
- Não logar valores de transação, saldos, credenciais nem chaves de acesso de NFC-e. Configure um filtro de log e teste isso.
- Endpoint de webhook validando origem/assinatura, com rate limit próprio.
- Upload de imagens: valide magic bytes (não a extensão), limite de tamanho, e sirva de fora do webroot.

---

## 14. Fases de entrega

**Fase 0 — Fundação.** Scaffold do Maven e do Next.js, docker-compose (postgres + backend + frontend + caddy), Flyway com schema inicial, `Money`, configuração de timezone, ArchUnit, pipeline de CI local, `CLAUDE.md`. Explique o `pom.xml` seção por seção — `parent`, `properties`, `dependencies`, `dependencyManagement`, `build/plugins` — e o que o `spring-boot-starter-parent` está resolvendo por baixo. Ao adicionar cada dependência, diga em uma frase o que ela faz e o que aconteceria sem ela. Explique também o ciclo do Flyway: onde as migrations ficam, a convenção de nomes, como ele sabe o que já rodou, e o que acontece se eu editar uma migration já aplicada. Entregável: `docker compose up` sobe tudo e o health check responde.

**Fase 1 — Domínio e CRUD.** Todas as entidades, repositórios, casos de uso e REST com OpenAPI. Cadastro manual de transação funcionando ponta a ponta. Testes com Testcontainers. Siga as regras didáticas da seção 3.1 — em especial, a armadilha do `BigDecimal.equals` aparece aqui, no `Money`. Entregável: consigo cadastrar e listar transações via API.

**Fase 2 — Ingestão bancária.** Cliente Pluggy, sync agendado, webhook, deduplicação, detector de transferência interna, parser de parcelamento, importador OFX/CSV/QIF e importação por print com tela de revisão e deduplicação cruzada (seção 6.1). Entregável: minhas transações reais aparecem no banco, sem duplicatas e sem contar transferência como gasto.

**Fase 3 — Categorização.** Motor de três camadas, seed de regras, aprendizado por correção, cache. Entregável: >80% das transações categorizadas sem intervenção.

**Fase 4 — Notas fiscais.** Parser de QR, providers por UF (MA e SP), extração por visão, armazenamento de imagem, e o `ReconciliationService` com scoring e `merchant_alias`. Faça o scorer em ciclo test-first, conforme a seção 12.3, e feche a fase com o teste de mutação. Entregável: envio uma URL de QR pela API e a nota é registrada, com itens, e vinculada à transação certa do cartão.

**Fase 5 — Frontend.** Todas as telas da seção 10, dark mode, PWA, rota de captura. Siga a ordem e as regras didáticas da seção 10.4 — comece pela tela de transações, não pelo dashboard. Entregável: uso o sistema pelo celular.

**Fase 6 — Assistente financeiro.** `FinancialProfile`, geração do snapshot em SQL, porta `AdviceProvider`, validação de números na saída do modelo, revisão mensal, cards acionáveis e chat sobre o snapshot (seção 11). Entregável: a revisão do mês me mostra pelo menos uma coisa que eu não tinha percebido sozinho, e todos os números dela conferem com o banco.

**Fase 7 — Produção.** Deploy na VPS, backup automatizado do Postgres (pg_dump diário com retenção), healthcheck, logs estruturados, e um runbook em `docs/`. Explique o `Caddyfile` linha por linha, como o Caddy obtém o certificado TLS, e desenhe em `docs/` a topologia de rede: quais portas ficam expostas na VPS, quais serviços só existem dentro da rede do compose, e por onde uma requisição minha passa até chegar no Postgres. Entregável: rodando 24/7 com backup verificado.

---

## 15. Comece assim

Não escreva código ainda. Primeiro:

1. Leia este documento inteiro e liste em `docs/questions.md` toda ambiguidade que você encontrou e que muda o modelo de dados.
2. Proponha o schema completo do banco (DDL) para eu revisar antes de virar migration.
3. Me diga o que você discorda das decisões que eu tomei aqui, se discordar de alguma.

Depois disso eu libero a Fase 0.