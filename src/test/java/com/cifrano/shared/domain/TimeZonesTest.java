package com.cifrano.shared.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.Month;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * A armadilha (SPEC seção 3.1, item 4): uma compra feita às 22h do dia 31 de
 * janeiro em São Paulo já é fevereiro em UTC. São Paulo está três horas
 * atrás de UTC (sem horário de verão desde 2019), então 31/01 22:00 vira
 * 01/02 01:00 em UTC — muda o dia E o mês.
 * <p>
 * O sistema inteiro guarda {@code Instant} em UTC (SPEC 4.2). Isso está
 * correto — o problema não é onde o dado é guardado, é ONDE ele é lido de
 * volta como calendário. Se o fechamento mensal extrai o mês do
 * {@code Instant} tratando-o como se já estivesse no fuso do usuário (ou
 * pior, como se UTC fosse "o fuso certo"), essa compra de 31/01 é contada em
 * fevereiro — o mês errado, na fatura errada.
 */
class TimeZonesTest {

    @Test
    void extractingTheCalendarMonthDirectlyFromUtcMisassignsALateNightPurchase() {
        // 31/01/2026 22:00 no horário de São Paulo (UTC-3).
        Instant lateNightPurchaseInSaoPaulo =
                ZonedDateTime.of(2026, 1, 31, 22, 0, 0, 0, TimeZones.SAO_PAULO).toInstant();

        // A armadilha: extrair o mês tratando o Instant como se já fosse
        // calendário UTC, sem passar pelo fuso do usuário.
        Month naiveMonthFromUtc = lateNightPurchaseInSaoPaulo.atZone(ZoneOffset.UTC).getMonth();

        assertThat(naiveMonthFromUtc)
                .as("uma compra de 31/01 às 22h em São Paulo vira 01/02 em UTC — o mês muda")
                .isEqualTo(Month.FEBRUARY);
    }

    @Test
    void convertingThroughSaoPauloBeforeExtractingTheMonthAssignsTheCorrectMonth() {
        Instant lateNightPurchaseInSaoPaulo =
                ZonedDateTime.of(2026, 1, 31, 22, 0, 0, 0, TimeZones.SAO_PAULO).toInstant();

        Month correctMonth = lateNightPurchaseInSaoPaulo.atZone(TimeZones.SAO_PAULO).getMonth();

        assertThat(correctMonth)
                .as("no fuso de quem fez a compra, ainda é janeiro")
                .isEqualTo(Month.JANUARY);
    }
}
