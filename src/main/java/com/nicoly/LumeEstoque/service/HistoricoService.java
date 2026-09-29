package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.HistoricoResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@Service
public class HistoricoService {

    private final JdbcTemplate jdbcTemplate;

    public HistoricoService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<HistoricoResponse> listar(String tipo, Long filialId) {
        StringBuilder sql = new StringBuilder("""
            SELECT m.id, m.created_at, m.produto_id, p.nome AS produto_nome,
                   m.filial_id, f.nome AS filial_nome, m.tipo,
                   m.quantidade_anterior, m.quantidade_nova, u.nome AS usuario_nome, m.motivo
            FROM movimentacoes m
            JOIN produtos p ON p.id = m.produto_id
            JOIN filiais f ON f.id = m.filial_id
            LEFT JOIN usuarios u ON u.id = m.usuario_id
            WHERE 1=1
        """);

        List<Object> params = new ArrayList<>();

        if (tipo != null && !tipo.trim().isEmpty()) {
            sql.append(" AND m.tipo::text = ?");
            params.add(tipo.trim());
        }

        if (filialId != null) {
            sql.append(" AND m.filial_id = ?");
            params.add(filialId);
        }

        sql.append(" ORDER BY m.created_at DESC, m.id DESC");

        return jdbcTemplate.query(sql.toString(), params.toArray(), (rs, rowNum) -> {
            String dataStr = "";
            java.sql.Timestamp ts = rs.getTimestamp("created_at");
            if (ts != null) {
                dataStr = ts.toLocalDateTime().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
            }

            return new HistoricoResponse(
                rs.getLong("id"),
                dataStr,
                rs.getLong("produto_id"),
                rs.getString("produto_nome"),
                rs.getLong("filial_id"),
                rs.getString("filial_nome"),
                rs.getString("tipo"),
                rs.getInt("quantidade_anterior"),
                rs.getInt("quantidade_nova"),
                rs.getString("usuario_nome") != null ? rs.getString("usuario_nome") : "Sistema",
                rs.getString("motivo")
            );
        });
    }
}
