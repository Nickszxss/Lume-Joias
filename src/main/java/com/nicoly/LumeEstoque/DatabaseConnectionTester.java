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

            List<Map<String, Object>> tables = jdbcTemplate.queryForList(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
            );
            System.out.println(">>> TABELAS EXISTENTES NO PUBLIC SCHEMA: <<<");
            for (Map<String, Object> t : tables) {
                String tableName = (String) t.get("table_name");
                System.out.println("Tabela: " + tableName);
                List<Map<String, Object>> cols = jdbcTemplate.queryForList(
                    "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = ?", tableName
                );
                for (Map<String, Object> col : cols) {
                    System.out.println("   - " + col.get("column_name") + " (" + col.get("data_type") + ")");
                }
            }

            List<Map<String, Object>> filiais = jdbcTemplate.queryForList("SELECT * FROM filiais ORDER BY id");
            System.out.println(">>> TABELA FILIAIS: <<<");
            for (Map<String, Object> filial : filiais) {
                System.out.println("   " + filial);
            }

            List<Map<String, Object>> produtos = jdbcTemplate.queryForList("SELECT * FROM produtos ORDER BY id");
            System.out.println(">>> TABELA PRODUTOS (total " + produtos.size() + "): <<<");
            for (Map<String, Object> p : produtos) {
                System.out.println("   " + p);
            }

            List<Map<String, Object>> estoques = jdbcTemplate.queryForList("SELECT * FROM estoques ORDER BY filial_id, produto_id");
            System.out.println(">>> TABELA ESTOQUES (total " + estoques.size() + "): <<<");
            for (Map<String, Object> e : estoques) {
                System.out.println("   " + e);
            }
        } catch (Exception e) {
            System.err.println(">>> FALHA NA CONEXÃO OU CONSULTA COM SUPABASE: " + e.getMessage() + " <<<");
            throw e;
        }
    }
}
