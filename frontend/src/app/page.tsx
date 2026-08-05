import { formatDate } from "@/lib/format";

// Um componente pode ser `async` — isso só é possível em Server Component
// (Client Component não pode ser função assíncrona; ele usa hooks como
// `useEffect` para buscar dado depois de já ter renderizado, um assunto da
// Fase 5). Aqui, como `Home` roda inteiramente no servidor, o React espera
// a Promise terminar (o `fetch` abaixo responder) antes de gerar o HTML —
// o navegador só recebe a página pronta, com o status do backend já
// dentro dela. Não existe "carregando..." piscando na tela nesta versão,
// porque não existe JavaScript nenhum rodando no cliente para buscar esse
// dado depois.
async function getBackendHealth(): Promise<{ status: string }> {
  // `process.env` lê variável de ambiente — nunca hardcode o endereço do
  // backend no código. Em desenvolvimento local (`npm run dev`, sem
  // Docker), o backend roda em `localhost:8080`. Dentro do docker-compose
  // (Fase 0, entregável final), os containers se enxergam pelo nome do
  // serviço na rede interna, não por `localhost` — por isso o
  // `docker-compose.yml` define `BACKEND_URL=http://backend:8080` para o
  // container do frontend, sobrescrevendo este valor padrão.
  const backendUrl = process.env.BACKEND_URL ?? "http://localhost:8080";

  try {
    // `cache: "no-store"` desliga o cache de fetch do Next.js para esta
    // chamada — sem isso, o Next poderia reaproveitar uma resposta antiga
    // e mostrar "UP" mesmo com o backend fora do ar. Um status de saúde
    // sempre precisa ser a leitura mais recente possível.
    const response = await fetch(`${backendUrl}/actuator/health`, {
      cache: "no-store",
    });

    if (!response.ok) {
      return { status: "DOWN" };
    }

    return (await response.json()) as { status: string };
  } catch {
    // `fetch` lança uma exceção (não devolve uma resposta com erro) quando
    // a conexão nem chega a acontecer — backend desligado, nome de host
    // errado, rede fora do ar. Sem este `catch`, essa falha derrubaria a
    // renderização da página inteira em vez de mostrar um status.
    return { status: "UNREACHABLE" };
  }
}

// `export default` é a convenção do App Router: o arquivo `page.tsx`
// exporta um componente como padrão, e o Next usa exatamente esse
// componente para renderizar a rota correspondente à pasta onde o arquivo
// está (`src/app/page.tsx` é a rota `/`).
export default async function Home() {
  const health = await getBackendHealth();

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-4 p-8">
      <h1 className="text-2xl font-medium text-foreground">Cifrano</h1>
      {/*
        `tabular-nums` é uma classe utilitária do Tailwind para
        `font-variant-numeric: tabular-nums` — faz cada dígito ocupar a
        mesma largura, então colunas de número (e aqui, o texto de status)
        não "dançam" horizontalmente quando o conteúdo muda. A seção 10.1
        do SPEC pede isso em toda coluna de valor monetário; aqui é só o
        primeiro lugar onde a classe aparece no projeto.
      */}
      <p className="font-mono text-sm tabular-nums text-muted">
        Backend: {health.status}
      </p>
      <p className="text-xs text-muted">{formatDate(new Date())}</p>
    </main>
  );
}
