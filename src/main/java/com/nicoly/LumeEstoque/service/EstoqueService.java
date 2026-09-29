package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.AjusteEstoqueRequest;
import com.nicoly.LumeEstoque.dto.AlertasResponse;
import com.nicoly.LumeEstoque.dto.EstoqueResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class EstoqueService {

    private final JdbcTemplate jdbcTemplate;

    public EstoqueService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<EstoqueResponse> listarEstoque(Long filialId) {
        String sql = """
            SELECT e.produto_id, e.filial_id, e.quantidade, e.status, p.nome AS produto_nome,
                   p.codigo AS sku, p.qtd_minima, f.nome AS filial_nome
            FROM estoques e
            JOIN produtos p ON p.id = e.produto_id
            JOIN filiais f ON f.id = e.filial_id
            """ + (filialId != null ? " WHERE e.filial_id = " + filialId : "") + """
            ORDER BY f.id, p.nome
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> {
            int qtd = rs.getInt("quantidade");
            int min = rs.getInt("qtd_minima");
            String status = rs.getString("status");
            if (status == null || status.trim().isEmpty()) {
                status = qtd == 0 ? "zerado" : (qtd <= min ? "baixo" : "suficiente");
            }

            return new EstoqueResponse(
                rs.getLong("produto_id"),
                rs.getLong("filial_id"),
                qtd,
                min,
                status,
                rs.getString("produto_nome"),
                rs.getString("filial_nome"),
                rs.getString("sku")
            );
        });
    }

    @Transactional
    public EstoqueResponse ajustarEstoque(AjusteEstoqueRequest req) {
        if (req.getQuantidade() == null || req.getQuantidade() <= 0) {
            throw new IllegalArgumentException("A quantidade deve ser maior que zero.");
        }
        if (req.getProdutoId() == null || req.getFilialId() == null) {
            throw new IllegalArgumentException("Produto e filial são obrigatórios.");
        }

        List<Map<String, Object>> prodRes = jdbcTemplate.queryForList(
            "SELECT nome, codigo, qtd_minima FROM produtos WHERE id = ?", req.getProdutoId()
        );
        if (prodRes.isEmpty()) {
            throw new IllegalArgumentException("Produto não encontrado.");
        }
        Map<String, Object> prod = prodRes.get(0);
        String produtoNome = (String) prod.get("nome");
        String sku = (String) prod.get("codigo");
        int qtdMinima = ((Number) prod.get("qtd_minima")).intValue();

        String filialNome = jdbcTemplate.queryForObject(
            "SELECT nome FROM filiais WHERE id = ?", String.class, req.getFilialId()
        );

        List<Map<String, Object>> estRes = jdbcTemplate.queryForList(
            "SELECT quantidade FROM estoques WHERE produto_id = ? AND filial_id = ?",
            req.getProdutoId(), req.getFilialId()
        );

        int qtdAnterior = estRes.isEmpty() ? 0 : ((Number) estRes.get(0).get("quantidade")).intValue();
        String tipo = req.getTipo() != null && req.getTipo().equalsIgnoreCase("saida") ? "saida" : "entrada";

        int qtdNova;
        if ("saida".equals(tipo)) {
            if (qtdAnterior < req.getQuantidade()) {
                throw new IllegalArgumentException("Não há quantidade suficiente em estoque para realizar esta retirada (Disponível: " + qtdAnterior + ").");
            }
            qtdNova = qtdAnterior - req.getQuantidade();
        } else {
            qtdNova = qtdAnterior + req.getQuantidade();
        }

        String status = qtdNova == 0 ? "zerado" : (qtdNova <= qtdMinima ? "baixo" : "suficiente");

        if (estRes.isEmpty()) {
            try {
                jdbcTemplate.update("""
                    INSERT INTO estoques (filial_id, produto_id, quantidade, status, updated_at)
                    VALUES (?, ?, ?, ?::status_estoque, CURRENT_TIMESTAMP)
                """, req.getFilialId(), req.getProdutoId(), qtdNova, status);
            } catch (Exception e) {
                jdbcTemplate.update("""
                    INSERT INTO estoques (filial_id, produto_id, quantidade, status, updated_at)
                    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
                """, req.getFilialId(), req.getProdutoId(), qtdNova, status);
            }
        } else {
            try {
                jdbcTemplate.update("""
                    UPDATE estoques SET quantidade = ?, status = ?::status_estoque, updated_at = CURRENT_TIMESTAMP
                    WHERE produto_id = ? AND filial_id = ?
                """, qtdNova, status, req.getProdutoId(), req.getFilialId());
            } catch (Exception e) {
                jdbcTemplate.update("""
                    UPDATE estoques SET quantidade = ?, status = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE produto_id = ? AND filial_id = ?
                """, qtdNova, status, req.getProdutoId(), req.getFilialId());
            }
        }

        Long usuarioId = resolverUsuarioId(req.getUsuario());
        String motivo = req.getMotivo() != null && !req.getMotivo().trim().isEmpty() ? req.getMotivo() : "Ajuste manual";

        try {
            jdbcTemplate.update("""
                INSERT INTO movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
                VALUES (?, ?, ?, ?::tipo_movimentacao, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            """, req.getProdutoId(), req.getFilialId(), usuarioId, tipo, req.getQuantidade(), qtdAnterior, qtdNova, motivo);
        } catch (Exception e) {
            jdbcTemplate.update("""
                INSERT INTO movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            """, req.getProdutoId(), req.getFilialId(), usuarioId, tipo, req.getQuantidade(), qtdAnterior, qtdNova, motivo);
        }

        return new EstoqueResponse(req.getProdutoId(), req.getFilialId(), qtdNova, qtdMinima, status, produtoNome, filialNome, sku);
    }

    public AlertasResponse listarAlertas(Long filialId) {
        List<EstoqueResponse> todos = listarEstoque(filialId);
        List<EstoqueResponse> alertas = new ArrayList<>();
        int baixo = 0;
        int zerado = 0;

        for (EstoqueResponse e : todos) {
            if ("zerado".equalsIgnoreCase(e.getStatus()) || e.getQuantidade() == 0) {
                zerado++;
                alertas.add(e);
            } else if ("baixo".equalsIgnoreCase(e.getStatus()) || e.getQuantidade() <= e.getQtdMinima()) {
                baixo++;
                alertas.add(e);
            }
        }

        return new AlertasResponse(baixo, zerado, alertas);
    }

    public Long resolverUsuarioId(String nomeOuEmail) {
        if (nomeOuEmail != null && !nomeOuEmail.trim().isEmpty()) {
            List<Map<String, Object>> u = jdbcTemplate.queryForList(
                "SELECT id FROM usuarios WHERE email = ? OR nome = ? LIMIT 1", nomeOuEmail, nomeOuEmail
            );
            if (!u.isEmpty()) {
                return ((Number) u.get(0).get("id")).longValue();
            }
        }
        List<Map<String, Object>> first = jdbcTemplate.queryForList("SELECT id FROM usuarios ORDER BY id LIMIT 1");
        return first.isEmpty() ? 1L : ((Number) first.get(0).get("id")).longValue();
    }
}
