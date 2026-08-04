package com.cifrano;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.base.DescribedPredicate.alwaysTrue;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.resideInAPackage;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;

/**
 * Testes de arquitetura, não de comportamento (SPEC seção 12.1): não
 * executam nenhum método do sistema, só inspecionam o bytecode compilado à
 * procura de dependências entre pacotes. A arquitetura hexagonal da seção 3
 * do SPEC existe em boa parte para isto ser possível — o domínio não
 * depende de framework, então testá-lo (e testar que ele *continua* sem
 * depender) é só instanciar a classe e chamar o método, sem subir Spring
 * nenhum. {@code @AnalyzeClasses} varre o bytecode de {@code com.cifrano}
 * uma vez, e cada {@code @ArchTest} roda uma regra contra esse mesmo
 * resultado.
 */
@AnalyzeClasses(packages = "com.cifrano", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    @ArchTest
    static final ArchRule domainDoesNotDependOnSpring =
            noClasses().that().resideInAPackage("..domain..")
                    .should().dependOnClassesThat().resideInAnyPackage("org.springframework..")
                    .because("o domínio é a parte do sistema que representa as regras de negócio "
                            + "puras (Money, o scorer da conciliação, os detectores...) e precisa "
                            + "continuar testável e compreensível sem subir um container Spring — "
                            + "é isso que SPEC seção 3 chama de arquitetura hexagonal");

    @ArchTest
    static final ArchRule domainDoesNotDependOnJpa =
            noClasses().that().resideInAPackage("..domain..")
                    .should().dependOnClassesThat().resideInAnyPackage("jakarta.persistence..")
                    .because("entidade JPA vive em adapter/out, mapeada explicitamente a partir do "
                            + "objeto de domínio — se o domínio importasse jakarta.persistence, essa "
                            + "fronteira deixaria de existir e o mapeamento explícito perderia o sentido");

    @ArchTest
    static final ArchRule adapterInDoesNotDependOnAdapterOut =
            noClasses().that().resideInAPackage("..adapter.in..")
                    .should().dependOnClassesThat().resideInAPackage("..adapter.out..")
                    .because("um controller (adapter/in) fala com o caso de uso (application), nunca "
                            + "direto com o repositório JPA (adapter/out) — pular a application é pular "
                            + "a regra de negócio que ela representa")
                    // Nenhum adapter/in ou adapter/out existe ainda nesta fase (nascem na
                    // Fase 1, com os primeiros controllers e repositórios). Sem
                    // allowEmptyShould, o ArchUnit 1.4+ falha uma regra que não encontrou
                    // nenhuma classe para checar, por padrão — proteção contra erro de
                    // digitação no nome do pacote passando despercebido como "sucesso".
                    // Aqui o pacote está certo, só ainda vazio; a regra passa a valer de
                    // verdade assim que a primeira classe cair em adapter/in.
                    .allowEmptyShould(true);

    /**
     * Cada módulo (account, transaction, category...) é uma fronteira; o
     * domínio de um não pode importar o domínio de outro diretamente, ou os
     * módulos deixam de ser independentes — trocar a implementação de um
     * arriscaria quebrar o outro por acoplamento escondido. {@code shared}
     * é a exceção deliberada: é onde vivem os tipos que todo módulo precisa
     * (Money, TimeZones), então toda dependência PARA {@code shared} é
     * ignorada por esta regra; só dependências entre dois módulos de
     * domínio de negócio (ex: account.domain → transaction.domain) violam.
     */
    @ArchTest
    static final ArchRule domainOfOneModuleDoesNotDependOnDomainOfAnother =
            slices().matching("com.cifrano.(*)..domain..")
                    .namingSlices("módulo $1")
                    .should().notDependOnEachOther()
                    .ignoreDependency(alwaysTrue(), resideInAPackage("com.cifrano.shared.."))
                    .because("módulos de domínio são fronteiras independentes (SPEC seção 3); "
                            + "shared é a exceção deliberada para tipos comuns como Money");

    @ArchTest
    static final ArchRule noDoubleFieldsForMoney =
            noFields().should().haveRawType(double.class)
                    .because("dinheiro nunca é double (SPEC seção 4.1) — double representa valor "
                            + "aproximado em ponto flutuante, e arredondamento de centavos que se "
                            + "acumula ao longo de milhares de transações produz um saldo que não bate "
                            + "com o extrato real");

    @ArchTest
    static final ArchRule noFloatFieldsForMoney =
            noFields().should().haveRawType(float.class)
                    .because("mesmo motivo do double, com ainda menos precisão");
}
