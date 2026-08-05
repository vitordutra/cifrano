// "use client" no topo do arquivo é uma diretiva do Next.js (não é
// JavaScript/TypeScript padrão) — ela marca este arquivo inteiro, e tudo
// que ele exporta, como "Client Component". No App Router do Next.js,
// **todo componente é Server Component por padrão**: o código roda no
// servidor, gera HTML, e manda só o HTML pronto para o navegador — o
// componente em si nunca chega a existir como JavaScript rodando no
// browser. Isso é ótimo para performance, mas quebra qualquer coisa que
// precise do navegador para existir: estado que muda com clique,
// `localStorage`, `window`, ouvir evento de teclado.
//
// O `next-themes` (a biblioteca por trás deste arquivo) precisa de duas
// coisas que só existem no navegador: ler `localStorage` para saber qual
// tema você escolheu da última vez, e adicionar/remover a classe `dark` no
// `<html>` quando você troca de tema. Nenhuma das duas existe no servidor.
// Por isso este componente — e só ele, não o `layout.tsx` inteiro — precisa
// da diretiva "use client".
"use client";

import { ThemeProvider as NextThemesProvider } from "next-themes";
import type { ComponentProps } from "react";

// Este arquivo não define lógica nova de tema — ele só reexporta o
// `ThemeProvider` da biblioteca com um nome de arquivo próprio do projeto.
// Por quê não importar `next-themes` direto no `layout.tsx`? Porque
// `layout.tsx` é Server Component, e importar algo marcado "use client"
// dentro dele é permitido (o Next isola a fronteira automaticamente), mas
// importar a biblioteca cliente-side direto misturaria a origem da
// diretiva. Isolar num arquivo próprio deixa explícito qual componente é
// "de cliente" e por quê — é o padrão recomendado para qualquer biblioteca
// de terceiros que só funciona no navegador.
//
// `ComponentProps<typeof NextThemesProvider>` é um tipo do TypeScript que
// significa "os mesmos props que o componente NextThemesProvider aceita" —
// em vez de copiar a lista de props à mão (e ela ficar desatualizada se a
// biblioteca mudar), o tipo é derivado automaticamente do componente real.
export function ThemeProvider({
  children,
  ...props
}: ComponentProps<typeof NextThemesProvider>) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>;
}
