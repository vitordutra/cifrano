package com.cifrano;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.HashSet;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Testa a fiação inteira: sobe um Postgres real em Docker (Testcontainers),
 * deixa o Spring Boot subir o contexto e apontar o {@link DataSource} para
 * esse container via {@code @ServiceConnection}, e confirma que o Flyway
 * rodou {@code V1__create_foundation.sql} num banco vazio sem erro.
 * <p>
 * É um {@code @SpringBootTest} — sobe o contexto inteiro, o mais caro dos
 * tipos de teste (SPEC seção 12.1) — porque o que este teste verifica é
 * exatamente a integração entre Spring Boot, Flyway e Postgres, não uma
 * fatia isolada. É por isso que o SPEC pede "poucos" testes deste tipo:
 * cada um paga o custo de inicializar toda a aplicação.
 * <p>
 * <b>Por que Testcontainers e não H2</b> (banco em memória): H2 aceita SQL
 * que o Postgres recusaria e recusa SQL que o Postgres aceita — não tem
 * {@code ON CONFLICT} do jeito que a seção 4.3 do SPEC depende, trata
 * {@code NUMERIC} e {@code TIMESTAMPTZ} de forma diferente, e o
 * {@code TRIGGER}/{@code FUNCTION} em PL/pgSQL desta migration nem existe
 * em H2. Um teste que passa contra um banco que não é o de produção é falsa
 * sensação de segurança — aqui é Postgres 16 de verdade, rodando em Docker,
 * criado e destruído só para este teste.
 */
@SpringBootTest
@Testcontainers
class FoundationMigrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:16-alpine");

    @Autowired
    DataSource dataSource;

    @Test
    void migrationsRunCleanlyAgainstAnEmptyDatabaseAndCreateTheFoundationTables() throws Exception {
        Set<String> tableNames = new HashSet<>();
        try (Connection connection = dataSource.getConnection();
             Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery(
                     "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")) {
            while (resultSet.next()) {
                tableNames.add(resultSet.getString("table_name"));
            }
        }

        assertThat(tableNames).contains(
                "institution", "account", "category", "bank_transaction",
                // flyway_schema_history é a tabela de controle do próprio Flyway
                // (SPEC seção 2) — registra o que já rodou e o checksum de cada
                // migration. Sua presença aqui prova que o Flyway de fato
                // executou, e não que as tabelas vieram de outro lugar.
                "flyway_schema_history");
    }

    @Test
    void categoryTriggerRejectsAGrandchildCategory() throws Exception {
        try (Connection connection = dataSource.getConnection();
             Statement statement = connection.createStatement()) {
            statement.execute("INSERT INTO category (code, name) VALUES ('FOOD', 'Alimentação')");
            statement.execute("""
                    INSERT INTO category (code, name, parent_id)
                    VALUES ('FOOD_GROCERIES', 'Supermercado', (SELECT id FROM category WHERE code = 'FOOD'))
                    """);

            assertThatThrownBy(() -> statement.execute("""
                    INSERT INTO category (code, name, parent_id)
                    VALUES ('FOOD_GROCERIES_ORGANIC', 'Orgânico', (SELECT id FROM category WHERE code = 'FOOD_GROCERIES'))
                    """))
                    .as("uma categoria que já é filha (FOOD_GROCERIES) não pode virar pai de outra")
                    .hasMessageContaining("already has a parent");
        }
    }
}
