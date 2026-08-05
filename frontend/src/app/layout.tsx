// Este arquivo NÃO tem "use client" no topo — então, pela regra do App
// Router explicada em `components/theme-provider.tsx`, ele é um Server
// Component. `RootLayout` roda no servidor, produz HTML, e é a moldura que
// envolve toda página do site: cabeçalho, rodapé, e qualquer coisa que
// deveria aparecer em toda tela ficaria aqui. Hoje ele só configura fonte,
// tema e a tag `<html>`/`<body>` — não tem cabeçalho nem rodapé ainda
// porque não existe navegação nenhuma no projeto além desta página única.
import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { ThemeProvider } from "@/components/theme-provider";
import "./globals.css";

// `Geist` e `Geist_Mono` são funções do Next.js que baixam e otimizam uma
// fonte do Google Fonts em tempo de build — a fonte fica hospedada junto
// com o resto do site (sem chamada externa ao Google Fonts em produção,
// o que seria mais lento e um vazamento de dado do visitante para o
// Google). `variable: "--font-geist-sans"` não aplica a fonte em lugar
// nenhum sozinho — ele só cria uma variável CSS com esse nome, disponível
// para o `globals.css` usar (veja `@theme inline` lá) e transformar em
// classe utilitária do Tailwind (`font-sans`).
const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// `Metadata` é um tipo do Next.js — não existe no HTML puro nem no React.
// Ele descreve o `<title>` e as tags `<meta>` da página, e o Next gera
// esse HTML sozinho a partir deste objeto. `export const metadata` é uma
// convenção especial de arquivo do App Router: qualquer `layout.tsx` ou
// `page.tsx` que exportar algo chamado exatamente `metadata` tem seu
// conteúdo lido pelo Next automaticamente — não é um import nem uma
// chamada de função, é convenção de nome reconhecida pelo framework.
export const metadata: Metadata = {
  title: "Cifrano",
  description: "Sistema de finanças pessoais",
};

// `RootLayout` é uma função que devolve marcação — essa é a definição
// mais simples de "componente React" que existe, e vale tanto para este
// arquivo (Server Component) quanto para `theme-provider.tsx` (Client
// Component): a diferença entre os dois não é a forma da função, é onde
// ela roda.
//
// `{ children }: LayoutProps<"/">` é "destructuring" de parâmetro: a
// função recebe um objeto só, e esta sintaxe já extrai o campo `children`
// dele direto, em vez de escrever `props.children` toda vez lá dentro.
// `children` é o conteúdo que fica DENTRO deste layout — no caso, o que
// `page.tsx` devolve. `LayoutProps<"/">` é um tipo gerado automaticamente
// pelo Next.js a partir da estrutura de pastas do projeto (o `"/"` é a
// rota raiz) — ele já sabe, sem você escrever a definição à mão, que este
// layout recebe `children` do tipo certo.
export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    // `suppressHydrationWarning` existe por causa do next-themes: o HTML
    // que o servidor gera não sabe ainda qual tema você escolheu (essa
    // informação mora no `localStorage` do navegador, que o servidor não
    // enxerga) — então o `next-themes`, já no navegador, ajusta a classe
    // do `<html>` logo na primeira renderização. Sem este atributo, o
    // React reclamaria (no console, em desenvolvimento) que o HTML do
    // servidor não bateu exatamente com o do navegador — um aviso de
    // "hidratação" que aqui é esperado e inofensivo, então é
    // explicitamente silenciado só nesta tag.
    <html
      lang="pt-BR"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <body className="min-h-full flex flex-col">
        {/*
          attribute="class": o next-themes controla o tema alternando a
          classe "dark" no <html> (é a classe que o globals.css espera).
          defaultTheme="dark" + enableSystem={false}: o tema começa sempre
          escuro, ignorando a preferência do sistema operacional — é a
          decisão da seção 10.1 ("dark mode como padrão"). Quando a Fase 5
          adicionar um botão de alternar tema, ele muda essa escolha via
          next-themes; não existe esse botão ainda.
        */}
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false}>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
