package com.nicoly.LumeEstoque;

import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

@Component
public class DatabaseConnectionTester implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    public DatabaseConnectionTester(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(String... args) throws Exception {
        System.out.println("=== TESTANDO CONEXÃO COM SUPABASE POSTGRESQL ===");
        try {
            String currentTime = jdbcTemplate.queryForObject("SELECT NOW()::text", String.class);
            System.out.println(">>> CONEXÃO COM SUPABASE BEM-SUCEDIDA! Hora no banco: " + currentTime + " <<<");

            List<Map<String, Object>> filiais = jdbcTemplate.queryForList("SELECT id, nome FROM filiais ORDER BY id LIMIT 5");
            System.out.println(">>> CONSULTA REALIZADA (Tabela filiais - registros encontrados: " + filiais.size() + "): <<<");
            for (Map<String, Object> filial : filiais) {
                System.out.println("   - ID: " + filial.get("id") + " | Nome: " + filial.get("nome"));
            }
        } catch (Exception e) {
            System.err.println(">>> FALHA NA CONEXÃO OU CONSULTA COM SUPABASE: " + e.getMessage() + " <<<");
            throw e;
        }
    }
}
