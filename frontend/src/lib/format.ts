// Este arquivo não tem nada de React — é TypeScript puro, sem JSX, sem
// componente. `lib/` é onde vive lógica que qualquer parte da tela pode
// importar e chamar como função normal. A regra (SPEC seção 10.3) é: toda
// formatação de moeda e data passa por aqui, nunca escrita solta dentro de
// uma tela — assim o formato muda num lugar só, e nenhuma tela esquece de
// usar o locale certo.
//
// `Intl` é uma API do próprio JavaScript (não é do React nem do Next), que
// sabe formatar número, moeda e data de acordo com as convenções de uma
// localidade (`locale`) — aqui, `"pt-BR"`. Sem ela, formatar R$ 1.234,56
// certinho (ponto no milhar, vírgula no decimal, símbolo antes do número)
// seria escrever essa lógica na mão.
//
// Criar o formatter uma vez, fora das funções, é proposital: `Intl.NumberFormat`
// faz um trabalho de preparação (carregar as regras da localidade) que não
// precisa ser refeito a cada chamada — criar um formatter por render seria
// desperdício. As duas constantes abaixo existem uma vez só, e as funções
// só chamam `.format(...)` nelas.
const currencyFormatter = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
});

const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
  // Mesma regra da seção 4.2 do SPEC vale na borda do frontend: o backend
  // manda o instante em UTC, e a conversão para o fuso de quem está usando
  // o app acontece aqui, na formatação — nunca antes disso.
  timeZone: "America/Sao_Paulo",
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
});

// `amount: number` é uma anotação de tipo do TypeScript: diz ao compilador
// (e a você, lendo o código depois) que este parâmetro só aceita número.
// Se alguém tentar chamar `formatCurrency("10")` (uma string), o TypeScript
// recusa a compilar — em JavaScript puro isso passaria despercebido até
// quebrar em produção. `: string` depois dos parênteses anota o tipo do
// retorno da função, pelo mesmo motivo.
export function formatCurrency(amount: number): string {
  return currencyFormatter.format(amount);
}

// `Date | string` é um "union type": este parâmetro aceita um objeto Date
// OU uma string, nunca outra coisa. É útil porque uma data pode chegar do
// backend como texto (JSON não tem tipo Date nativo, então API sempre
// manda string) ou já pode ter sido convertida para Date em algum ponto
// anterior do código — a função aceita os dois casos e normaliza por
// dentro, em vez de forçar quem chama a converter antes.
export function formatDate(date: Date | string): string {
  return dateFormatter.format(typeof date === "string" ? new Date(date) : date);
}
