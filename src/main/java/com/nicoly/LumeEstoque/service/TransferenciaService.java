package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.AjusteEstoqueRequest;
import com.nicoly.LumeEstoque.dto.TransferenciaRequest;
import com.nicoly.LumeEstoque.dto.TransferenciaResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@Service
public class TransferenciaService {

    private final JdbcTemplate jdbcTemplate;
    private final EstoqueService estoqueService;

    public TransferenciaService(JdbcTemplate jdbcTemplate, EstoqueService estoqueService) {
        this.jdbcTemplate = jdbcTemplate;
        this.estoqueService = estoqueService;
    }

    public List<TransferenciaResponse> listarTodas() {
        String sql = """
            SELECT t.id, t.created_at, t.produto_id, p.nome AS produto_nome,
                   t.origem_id, fo.nome AS origem_nome,
                   t.destino_id, fd.nome AS destino_nome,
                   t.quantidade, u.nome AS solicitante_nome, t.status
            FROM transferencias t
            JOIN produtos p ON p.id = t.produto_id
            JOIN filiais fo ON fo.id = t.origem_id
            JOIN filiais fd ON fd.id = t.destino_id
            LEFT JOIN usuarios u ON u.id = t.usuario_id
            ORDER BY t.created_at DESC, t.id DESC
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> {
            String dataStr = "";
            java.sql.Timestamp ts = rs.getTimestamp("created_at");
            if (ts != null) {
                dataStr = ts.toLocalDateTime().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
            }

            return new TransferenciaResponse(
                rs.getLong("id"),
                rs.getLong("produto_id"),
                rs.getString("produto_nome"),
                rs.getLong("origem_id"),
                rs.getString("origem_nome"),
                rs.getLong("destino_id"),
                rs.getString("destino_nome"),
                rs.getInt("quantidade"),
                rs.getString("solicitante_nome") != null ? rs.getString("solicitante_nome") : "Sistema",
                dataStr,
                rs.getString("status")
            );
        });
    }

    @Transactional
    public TransferenciaResponse solicitar(TransferenciaRequest req) {
        if (req.getOrigemId() == null || req.getDestinoId() == null) {
            throw new IllegalArgumentException("Origem e Destino são obrigatórios.");
        }
        if (req.getOrigemId().equals(req.getDestinoId())) {
            throw new IllegalArgumentException("A filial de origem e de destino devem ser diferentes.");
        }
        if (req.getQuantidade() == null || req.getQuantidade() <= 0) {
            throw new IllegalArgumentException("A quantidade deve ser maior que zero.");
        }
        if (req.getProdutoId() == null) {
            throw new IllegalArgumentException("Produto é obrigatório.");
        }

        List<Map<String, Object>> est = jdbcTemplate.queryForList(
            "SELECT quantidade FROM estoques WHERE produto_id = ? AND filial_id = ?",
            req.getProdutoId(), req.getOrigemId()
        );
        int qtdOrigem = est.isEmpty() ? 0 : ((Number) est.get(0).get("quantidade")).intValue();
        if (qtdOrigem < req.getQuantidade()) {
            throw new IllegalArgumentException("A quantidade solicitada (" + req.getQuantidade() + ") excede o estoque disponível na filial de origem (" + qtdOrigem + ").");
        }

        Long usuarioId = estoqueService.resolverUsuarioId(req.getSolicitante());

        jdbcTemplate.update("""
            INSERT INTO transferencias (origem_id, destino_id, produto_id, usuario_id, quantidade, status, observacao, created_at)
            VALUES (?, ?, ?, ?, ?, 'solicitada'::status_transferencia, ?, CURRENT_TIMESTAMP)
        """, req.getOrigemId(), req.getDestinoId(), req.getProdutoId(), usuarioId, req.getQuantidade(), req.getObservacao());

        Long id = jdbcTemplate.queryForObject("SELECT MAX(id) FROM transferencias", Long.class);

        String produtoNome = jdbcTemplate.queryForObject("SELECT nome FROM produtos WHERE id = ?", String.class, req.getProdutoId());
        String origemNome = jdbcTemplate.queryForObject("SELECT nome FROM filiais WHERE id = ?", String.class, req.getOrigemId());
        String destinoNome = jdbcTemplate.queryForObject("SELECT nome FROM filiais WHERE id = ?", String.class, req.getDestinoId());

        return new TransferenciaResponse(id, req.getProdutoId(), produtoNome, req.getOrigemId(), origemNome, req.getDestinoId(), destinoNome, req.getQuantidade(), req.getSolicitante(), "Hoje", "solicitada");
    }

    @Transactional
    public TransferenciaResponse concluir(Long id) {
        List<Map<String, Object>> res = jdbcTemplate.queryForList(
            "SELECT id, origem_id, destino_id, produto_id, quantidade, status FROM transferencias WHERE id = ?", id
        );

        if (res.isEmpty()) {
            throw new IllegalArgumentException("Transferência não encontrada.");
        }

        Map<String, Object> t = res.get(0);
        String statusAtual = (String) t.get("status");
        if ("concluida".equalsIgnoreCase(statusAtual)) {
            throw new IllegalArgumentException("Esta transferência já foi concluída.");
        }

        long produtoId = ((Number) t.get("produto_id")).longValue();
        long origemId = ((Number) t.get("origem_id")).longValue();
        long destinoId = ((Number) t.get("destino_id")).longValue();
        int qtd = ((Number) t.get("quantidade")).intValue();

        AjusteEstoqueRequest reqSaida = new AjusteEstoqueRequest();
        reqSaida.setProdutoId(produtoId);
        reqSaida.setFilialId(origemId);
        reqSaida.setTipo("saida");
        reqSaida.setQuantidade(qtd);
        reqSaida.setMotivo("Transferência para Filial #" + destinoId);
        reqSaida.setUsuario("Transferência #" + id);
        estoqueService.ajustarEstoque(reqSaida);

        AjusteEstoqueRequest reqEntrada = new AjusteEstoqueRequest();
        reqEntrada.setProdutoId(produtoId);
        reqEntrada.setFilialId(destinoId);
        reqEntrada.setTipo("entrada");
        reqEntrada.setQuantidade(qtd);
        reqEntrada.setMotivo("Transferência recebida da Filial #" + origemId);
        reqEntrada.setUsuario("Transferência #" + id);
        estoqueService.ajustarEstoque(reqEntrada);

        jdbcTemplate.update("""
            UPDATE transferencias SET status = 'concluida'::status_transferencia, concluida_at = CURRENT_TIMESTAMP WHERE id = ?
        """, id);

        String produtoNome = jdbcTemplate.queryForObject("SELECT nome FROM produtos WHERE id = ?", String.class, produtoId);
        String origemNome = jdbcTemplate.queryForObject("SELECT nome FROM filiais WHERE id = ?", String.class, origemId);
        String destinoNome = jdbcTemplate.queryForObject("SELECT nome FROM filiais WHERE id = ?", String.class, destinoId);

        return new TransferenciaResponse(id, produtoId, produtoNome, origemId, origemNome, destinoId, destinoNome, qtd, "Sistema", "Hoje", "concluida");
    }
}
