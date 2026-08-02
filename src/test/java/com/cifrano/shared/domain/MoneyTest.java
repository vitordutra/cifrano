package com.cifrano.shared.domain;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Currency;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MoneyTest {

    private static final Currency BRL = Currency.getInstance("BRL");

    @Test
    void addingTwoAmountsInTheSameCurrencySumsThem() {
        Money a = new Money(new BigDecimal("100.00"), BRL);
        Money b = new Money(new BigDecimal("50.00"), BRL);

        assertThat(a.add(b)).isEqualTo(new Money(new BigDecimal("150.00"), BRL));
    }

    @Test
    void subtractingReducesTheAmount() {
        Money a = new Money(new BigDecimal("100.00"), BRL);
        Money b = new Money(new BigDecimal("30.00"), BRL);

        assertThat(a.subtract(b)).isEqualTo(new Money(new BigDecimal("70.00"), BRL));
    }

    @Test
    void negatingFlipsTheSign() {
        Money expense = new Money(new BigDecimal("45.00"), BRL);

        assertThat(expense.negate().amount()).isEqualByComparingTo("-45.00");
    }

    @Test
    void negativeAmountIsRecognizedAsNegative() {
        Money expense = new Money(new BigDecimal("-45.00"), BRL);

        assertThat(expense.isNegative()).isTrue();
    }

    @Test
    void zeroOrPositiveAmountIsNotNegative() {
        assertThat(new Money(BigDecimal.ZERO, BRL).isNegative()).isFalse();
        assertThat(new Money(new BigDecimal("10.00"), BRL).isNegative()).isFalse();
    }

    @Test
    void operatingOnDifferentCurrenciesIsRejected() {
        Money brl = new Money(new BigDecimal("10.00"), BRL);
        Money usd = new Money(new BigDecimal("10.00"), Currency.getInstance("USD"));

        assertThatThrownBy(() -> brl.add(usd)).isInstanceOf(IllegalArgumentException.class);
    }

    /**
     * A armadilha (SPEC seção 3.1, item 1): {@code BigDecimal.equals}
     * compara também a ESCALA, não só o valor matemático.
     * {@code new BigDecimal("10.00").equals(new BigDecimal("10.0"))} é
     * {@code false}, porque "10.00" tem escala 2 e "10.0" tem escala 1 —
     * apesar de representarem a mesma quantia.
     * <p>
     * Um {@code record} gera {@code equals} comparando cada componente com
     * o {@code equals} dele. Sem um {@code equals} próprio em {@link Money},
     * este teste falha: duas quantias que valem o mesmo dinheiro (R$ 10,00 é
     * R$ 10,0) são tratadas como diferentes só porque uma delas chegou de
     * uma fonte que formatou o número com uma casa decimal a menos — por
     * exemplo, um provedor bancário que manda "10.0" em vez de "10.00".
     * Dois saldos que deveriam bater deixam de bater, e uma reconciliação
     * ou um teste de igualdade de totais quebra por um motivo que não tem
     * nada a ver com dinheiro estar errado.
     */
    @Test
    void monetaryValuesThatAreMathematicallyEqualAreEqualRegardlessOfScale() {
        Money tenWithTwoDecimals = new Money(new BigDecimal("10.00"), BRL);
        Money tenWithOneDecimal = new Money(new BigDecimal("10.0"), BRL);

        assertThat(tenWithTwoDecimals).isEqualTo(tenWithOneDecimal);
    }
}
