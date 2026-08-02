# Cifrano

Sistema de finanças pessoais, single-user, self-hosted. Java 21 + Spring Boot (Maven) no backend, Next.js 15 no frontend, PostgreSQL.

**A especificação completa está em `docs/SPEC.md`. Leia antes de qualquer trabalho.** Este arquivo tem só o que se repete todo dia; o SPEC tem as decisões, as regras de negócio e as fases.

## Estado atual

Fase atual: **0 — Fundação** (atualize esta linha ao concluir cada fase).

## Comandos

```bash
./mvnw test                       # testes do backend
./mvnw spring-boot:run            # sobe o backend
docker compose up -d              # sobe tudo
cd frontend && npm run dev        # frontend em dev
cd frontend && npm run lint       # lint do frontend
```

## Regras que valem em todo turno

- **Este projeto é para eu aprender.** Explique o que introduzir: anotações, recursos da linguagem, padrões, bibliotecas. Detalhes em `docs/SPEC.md` seções 3.1 (backend/Java), 10.4 (React/Next.js) e 12 (testes).
- **Trabalhe em fases.** Ao terminar a fase, pare e me apresente o resumo. Não avance sem eu mandar.
- **Commits pequenos e atômicos**, Conventional Commits, corpo explicando o porquê. Sem `Co-authored-by` nem qualquer menção a ferramenta de IA.
- **Nunca `double` para dinheiro.** `Money` (BigDecimal + Currency) em toda a aplicação. Despesa é negativa, receita é positiva.
- **Tempo:** `Instant` em UTC no domínio e no banco. `America/Sao_Paulo` só na borda.
- **Domínio não importa Spring nem JPA.** ArchUnit garante isso.
- **Nunca edite uma migration já aplicada.** Crie a próxima.
- **Nunca logue valores, saldos, credenciais ou chave de acesso de NFC-e.**
- Confirme contratos de API externa na documentação oficial antes de integrar. Não invente campo.
- Se algo estiver ambíguo e mudar o modelo de dados, pergunte em vez de supor.
- **Todo o código é em inglês.** Nomes de pacote, classe, método, variável, enum,
  constante; nomes de teste; mensagens de exceção; chaves de configuração; rotas e
  campos de JSON. **O banco inteiro também** — DDL e DML: tabelas, colunas,
  constraints, índices, valores de enum persistidos e arquivos de migration.
  **A documentação é em português** (`docs/`), porque é material de estudo — e o
  glossário faz a ponte, trazendo o termo em português junto do identificador em
  inglês que ele virou no código. Mensagens de commit em inglês.
  Nome de teste descreve a regra de negócio: `creditCardBillPaymentIsNotAnExpense()`,
  nunca `testDetect()`.

## Documentação que você mantém

- `docs/dominio/glossario.md` — todo termo financeiro/contábil, no mesmo commit em que ele entra no código
- `docs/aprendizado/fase-N.md` — ao final de cada fase (tecnologia + negócio)
- `docs/adr/` — decisões arquiteturais