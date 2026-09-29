package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.ProdutoRequest;
import com.nicoly.LumeEstoque.dto.ProdutoResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ProdutoService {

    private final JdbcTemplate jdbcTemplate;

    public ProdutoService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<ProdutoResponse> listarTodos() {
        String sql = "SELECT id, nome, codigo, descricao, unidade_medida, qtd_minima, ativo FROM produtos WHERE ativo = true ORDER BY id";
        return jdbcTemplate.query(sql, (rs, rowNum) -> new ProdutoResponse(
            rs.getLong("id"),
            rs.getString("nome"),
            rs.getString("codigo"),
            rs.getString("descricao"),
            rs.getString("unidade_medida"),
            rs.getInt("qtd_minima"),
            rs.getBoolean("ativo")
        ));
    }

    @Transactional
    public ProdutoResponse criarProduto(ProdutoRequest request) {
        String codigo = request.getSku();
        if (codigo == null || codigo.trim().isEmpty()) {
            throw new IllegalArgumentException("SKU/Código do produto é obrigatório.");
        }
        if (request.getNome() == null || request.getNome().trim().isEmpty()) {
            throw new IllegalArgumentException("Nome do produto é obrigatório.");
        }

        Integer existingCount = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM produtos WHERE codigo = ?", Integer.class, codigo
        );
        if (existingCount != null && existingCount > 0) {
            throw new IllegalArgumentException("Já existe um produto cadastrado com o SKU/Código: " + codigo);
        }

        String unidade = request.getUnidadeMedida() != null ? request.getUnidadeMedida() : "unidade";
        int qtdMinima = request.getQtdMinima() != null ? request.getQtdMinima() : 10;
        int qtdInicial = request.getQtdInicial() != null ? request.getQtdInicial() : 0;

        jdbcTemplate.update("""
            INSERT INTO produtos (nome, descricao, codigo, unidade_medida, qtd_minima, ativo)
            VALUES (?, ?, ?, ?, ?, true)
        """, request.getNome(), request.getDescricao(), codigo, unidade, qtdMinima);

        Long produtoId = jdbcTemplate.queryForObject(
            "SELECT id FROM produtos WHERE codigo = ?", Long.class, codigo
        );

        String status = qtdInicial == 0 ? "zerado" : (qtdInicial <= qtdMinima ? "baixo" : "suficiente");

        for (long filialId = 1; filialId <= 5; filialId++) {
            try {
                jdbcTemplate.update("""
                    INSERT INTO estoques (filial_id, produto_id, quantidade, status, updated_at)
                    VALUES (?, ?, ?, ?::status_estoque, CURRENT_TIMESTAMP)
                """, filialId, produtoId, qtdInicial, status);
            } catch (Exception e1) {
                jdbcTemplate.update("""
                    INSERT INTO estoques (filial_id, produto_id, quantidade, status, updated_at)
                    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
                """, filialId, produtoId, qtdInicial, status);
            }
        }

        return new ProdutoResponse(produtoId, request.getNome(), codigo, request.getDescricao(), request.getCategoria(), qtdMinima, true);
    }
}
