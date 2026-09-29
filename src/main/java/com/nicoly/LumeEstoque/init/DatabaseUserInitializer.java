package com.nicoly.LumeEstoque.init;

import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class DatabaseUserInitializer implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;
    private final BCryptPasswordEncoder passwordEncoder;

    public DatabaseUserInitializer(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
        this.passwordEncoder = new BCryptPasswordEncoder();
    }

    @Override
    public void run(String... args) throws Exception {
        System.out.println("=== INICIALIZANDO/VERIFICANDO TABELA DE USUÁRIOS NO SUPABASE ===");
        try {
            // Garantir que a tabela e colunas necessárias existam
            jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS usuarios (
                    id BIGSERIAL PRIMARY KEY,
                    nome VARCHAR(250) NOT NULL,
                    email VARCHAR(250) NOT NULL UNIQUE,
                    senha VARCHAR(250) NOT NULL,
                    cargo VARCHAR(50),
                    filial_id BIGINT,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
            """);

            jdbcTemplate.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS cargo VARCHAR(50);");

            cadastrarOuVerificarUsuario("Anderson", "anderson.func@empresa.com", "etec2026@DS", "funcionario", 1L);
            cadastrarOuVerificarUsuario("Robson", "robson.grt@empresa.com", "etec2026@DS", "gerente", null);
            cadastrarOuVerificarUsuario("Isabella", "isabella.func@empresa.com", "etec2026@DS", "funcionario", 2L);
            cadastrarOuVerificarUsuario("Manuella", "manuella.grt@empresa.com", "etec2026@DS", "gerente", null);

            System.out.println(">>> INICIALIZAÇÃO DE USUÁRIOS CONCLUÍDA COM SUCESSO! <<<");
        } catch (Exception e) {
            System.err.println(">>> ERRO AO INICIALIZAR USUÁRIOS NO BANCO DE DADOS: " + e.getMessage() + " <<<");
            throw e;
        }
    }

    private void cadastrarOuVerificarUsuario(String nome, String email, String senhaPura, String cargo, Long filialId) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM usuarios WHERE email = ?",
            Integer.class,
            email
        );

        if (count == null || count == 0) {
            String senhaHash = passwordEncoder.encode(senhaPura);
            jdbcTemplate.update(
                "INSERT INTO usuarios (nome, email, senha, cargo, tipo, filial_id) VALUES (?, ?, ?, ?, ?::tipo_usuario, ?)",
                nome, email, senhaHash, cargo, cargo, filialId
            );
            System.out.println("   - Usuário cadastrado: " + email + " (" + cargo + ")");
        } else {
            String senhaExistente = jdbcTemplate.queryForObject(
                "SELECT senha FROM usuarios WHERE email = ?",
                String.class,
                email
            );
            if (senhaExistente == null || !passwordEncoder.matches(senhaPura, senhaExistente)) {
                String novaSenhaHash = passwordEncoder.encode(senhaPura);
                jdbcTemplate.update(
                    "UPDATE usuarios SET nome = ?, senha = ?, cargo = ?, tipo = ?::tipo_usuario, filial_id = ? WHERE email = ?",
                    nome, novaSenhaHash, cargo, cargo, filialId, email
                );
                System.out.println("   - Usuário atualizado: " + email + " (" + cargo + ")");
            } else {
                jdbcTemplate.update(
                    "UPDATE usuarios SET nome = ?, cargo = ?, tipo = ?::tipo_usuario, filial_id = ? WHERE email = ?",
                    nome, cargo, cargo, filialId, email
                );
                System.out.println("   - Usuário já existe e verificado: " + email + " (" + cargo + ")");
            }
        }
    }
}
