package com.cifrano.shared.domain;

import java.math.BigDecimal;
import java.util.Currency;
import java.util.Objects;

/**
 * Value object monetário (SPEC seção 4.1). Despesa é negativa, receita é
 * positiva — essa convenção de sinal é responsabilidade de quem constrói o
 * Money na borda do sistema, não deste tipo.
 * <p>
 * {@code record} em vez de classe: um {@code record} declara os campos uma
 * vez só e o compilador gera construtor, getters ({@code amount()},
 * {@code currency()}), {@code equals}/{@code hashCode}/{@code toString} a
 * partir deles. Não existe setter — os campos são {@code final}, então
 * qualquer "alteração" (como {@link #add}) precisa criar um Money novo. É
 * exatamente a imutabilidade que dinheiro exige: uma instância de Money
 * nunca muda de valor depois de criada, então pode ser compartilhada entre
 * threads e caches sem risco de alguém alterá-la debaixo do outro.
 */
public record Money(BigDecimal amount, Currency currency) {

    /**
     * Este bloco é o "compact constructor" do record — roda antes dos
     * campos serem atribuídos, sem repetir a lista de parâmetros. Serve
     * para validar ou normalizar entrada; aqui só valida que nada é nulo,
     * porque {@code Optional} como campo é anti-padrão (SPEC seção 3.1) e
     * BigDecimal/Currency não têm um "vazio" que sirva como sentinela.
     */
    public Money {
        Objects.requireNonNull(amount, "amount must not be null");
        Objects.requireNonNull(currency, "currency must not be null");
    }

    public Money add(Money other) {
        requireSameCurrency(other);
        return new Money(amount.add(other.amount), currency);
    }

    public Money subtract(Money other) {
        requireSameCurrency(other);
        return new Money(amount.subtract(other.amount), currency);
    }

    public Money negate() {
        return new Money(amount.negate(), currency);
    }

    public boolean isNegative() {
        return amount.signum() < 0;
    }

    private void requireSameCurrency(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException(
                    "cannot operate on Money with different currencies: %s and %s"
                            .formatted(currency, other.currency));
        }
    }
}
