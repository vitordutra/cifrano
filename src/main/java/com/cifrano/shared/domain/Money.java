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

    /**
     * Sobrescreve o {@code equals} gerado pelo record. {@link BigDecimal#equals}
     * compara escala além de valor — "10.00" e "10.0" são objetos diferentes
     * para ele, apesar de representarem a mesma quantia (ver o teste que
     * provou isso no commit anterior). {@link BigDecimal#compareTo} ignora
     * escala e compara só o valor matemático, que é a igualdade que dinheiro
     * precisa: R$ 10,00 é R$ 10,00, não importa quantas casas decimais o
     * texto de origem trazia.
     */
    @Override
    public boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof Money other)) {
            return false;
        }
        return amount.compareTo(other.amount) == 0 && currency.equals(other.currency);
    }

    /**
     * {@code hashCode} precisa ser consistente com {@code equals}: dois
     * objetos iguais têm que produzir o mesmo hash, senão Money quebra
     * silenciosamente dentro de um {@code HashSet} ou como chave de
     * {@code HashMap} — duas quantias iguais poderiam parar em posições
     * diferentes da tabela hash e nunca serem encontradas uma pela outra.
     * {@link BigDecimal#stripTrailingZeros()} normaliza "10.00" e "10.0"
     * para a mesma representação mínima antes de calcular o hash, então
     * valores iguais por {@code compareTo} sempre produzem o mesmo hash.
     */
    @Override
    public int hashCode() {
        return Objects.hash(amount.stripTrailingZeros(), currency);
    }
}
