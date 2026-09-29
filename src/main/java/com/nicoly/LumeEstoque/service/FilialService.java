package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.FilialResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class FilialService {

    private final JdbcTemplate jdbcTemplate;

    public FilialService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<FilialResponse> listarTodas() {
        String sql = "SELECT id, nome, endereco, cidade, estado, ativa FROM filiais ORDER BY id";
        return jdbcTemplate.query(sql, (rs, rowNum) -> new FilialResponse(
            rs.getLong("id"),
            rs.getString("nome"),
            rs.getString("endereco"),
            rs.getString("cidade"),
            rs.getString("estado"),
            rs.getBoolean("ativa")
        ));
    }
}
