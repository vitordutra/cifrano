package com.cifrano.shared.domain;

import java.time.ZoneId;

/**
 * SPEC seção 4.2: o sistema guarda tudo em {@code Instant} (UTC) no domínio
 * e no banco, e converte para o fuso de São Paulo só na borda — os pontos
 * onde o dado entra ou sai (a data que o usuário digita, o JSON que o
 * controller devolve, o agrupamento do relatório mensal). Esta é a
 * constante única desse fuso, para nunca aparecer um {@code "America/Sao_Paulo"}
 * escrito à mão em mais de um lugar do código.
 */
public final class TimeZones {

    public static final ZoneId SAO_PAULO = ZoneId.of("America/Sao_Paulo");

    private TimeZones() {
    }
}
