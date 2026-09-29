package com.nicoly.LumeEstoque.repository;

import com.nicoly.LumeEstoque.model.Usuario;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.Optional;

@Repository
public class UsuarioRepository {

    private final JdbcTemplate jdbcTemplate;

    public UsuarioRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    private final RowMapper<Usuario> userRowMapper = (rs, rowNum) -> {
        Usuario usuario = new Usuario();
        usuario.setId(rs.getLong("id"));
        usuario.setNome(rs.getString("nome"));
        usuario.setEmail(rs.getString("email"));
        usuario.setSenha(rs.getString("senha"));

        // Tratar cargo e tipo se existirem
        try { usuario.setCargo(rs.getString("cargo")); } catch (Exception ignored) {}
        try {
            Object tipoObj = rs.getObject("tipo");
            if (tipoObj != null) {
                usuario.setTipo(tipoObj.toString());
            }
        } catch (Exception ignored) {}

        if (usuario.getCargo() == null && usuario.getTipo() != null) {
            usuario.setCargo(usuario.getTipo());
        }
        if (usuario.getTipo() == null && usuario.getCargo() != null) {
            usuario.setTipo(usuario.getCargo());
        }

        usuario.setFilialId(rs.getObject("filial_id", Long.class));
        try {
            usuario.setCreatedAt(rs.getObject("created_at", OffsetDateTime.class));
        } catch (Exception ignored) {}

        return usuario;
    };

    public Optional<Usuario> buscarPorEmail(String email) {
        if (email == null || email.trim().isEmpty()) {
            return Optional.empty();
        }
        try {
            Usuario usuario = jdbcTemplate.queryForObject(
                "SELECT id, nome, email, senha, cargo, tipo::text as tipo, filial_id, created_at FROM usuarios WHERE email = ?",
                userRowMapper,
                email.trim()
            );
            return Optional.ofNullable(usuario);
        } catch (EmptyResultDataAccessException e) {
            return Optional.empty();
        }
    }
}
