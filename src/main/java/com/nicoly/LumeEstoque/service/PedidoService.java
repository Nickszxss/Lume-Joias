package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.PedidoCompraRequest;
import com.nicoly.LumeEstoque.dto.PedidoCompraResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@Service
public class PedidoService {

    private final JdbcTemplate jdbcTemplate;
    private final EstoqueService estoqueService;

    public PedidoService(JdbcTemplate jdbcTemplate, EstoqueService estoqueService) {
        this.jdbcTemplate = jdbcTemplate;
        this.estoqueService = estoqueService;
    }

    public List<PedidoCompraResponse> listarTodos() {
        String sql = """
            SELECT pc.id, pc.created_at, ipc.produto_id, p.nome AS produto_nome,
                   ipc.quantidade, pc.filial_id, f.nome AS filial_nome,
                   u.nome AS solicitante_nome, pc.status
            FROM pedidos_compra pc
            LEFT JOIN itens_pedido_compra ipc ON ipc.pedido_id = pc.id
            LEFT JOIN produtos p ON p.id = ipc.produto_id
            JOIN filiais f ON f.id = pc.filial_id
            LEFT JOIN usuarios u ON u.id = pc.usuario_id
            ORDER BY pc.created_at DESC, pc.id DESC
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> {
            String dataStr = "";
            java.sql.Timestamp ts = rs.getTimestamp("created_at");
            if (ts != null) {
                dataStr = ts.toLocalDateTime().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
            }

            return new PedidoCompraResponse(
                rs.getLong("id"),
                rs.getLong("produto_id"),
                rs.getString("produto_nome") != null ? rs.getString("produto_nome") : "Produto Geral",
                rs.getInt("quantidade"),
                rs.getLong("filial_id"),
                rs.getString("filial_nome"),
                rs.getString("solicitante_nome") != null ? rs.getString("solicitante_nome") : "Gerente",
                dataStr,
                rs.getString("status")
            );
        });
    }

    @Transactional
    public PedidoCompraResponse criar(PedidoCompraRequest req, String userCargoOuEmail) {
        if (req.getQuantidade() == null || req.getQuantidade() <= 0) {
            throw new IllegalArgumentException("A quantidade do pedido deve ser maior que zero.");
        }
        if (req.getProdutoId() == null || req.getFilialId() == null) {
            throw new IllegalArgumentException("Produto e Filial são obrigatórios.");
        }

        String solicitante = req.getSolicitante();
        if (userCargoOuEmail != null && ("funcionario".equalsIgnoreCase(userCargoOuEmail) || userCargoOuEmail.contains("func"))) {
            throw new SecurityException("Apenas gerentes podem realizar pedidos de compra.");
        }

        Long usuarioId = estoqueService.resolverUsuarioId(solicitante);

        List<Map<String, Object>> usrInfo = jdbcTemplate.queryForList(
            "SELECT cargo, tipo FROM usuarios WHERE id = ?", usuarioId
        );
        if (!usrInfo.isEmpty()) {
            String cargo = (String) usrInfo.get(0).get("cargo");
            Object tipo = usrInfo.get(0).get("tipo");
            String tipoStr = tipo != null ? tipo.toString() : cargo;
            if ("funcionario".equalsIgnoreCase(cargo) || "funcionario".equalsIgnoreCase(tipoStr)) {
                throw new SecurityException("Apenas gerentes podem realizar pedidos de compra.");
            }
        }

        jdbcTemplate.update("""
            INSERT INTO pedidos_compra (filial_id, usuario_id, status, observacao, created_at)
            VALUES (?, ?, 'aberto'::status_pedido, ?, CURRENT_TIMESTAMP)
        """, req.getFilialId(), usuarioId, req.getObservacao());

        Long pedidoId = jdbcTemplate.queryForObject("SELECT MAX(id) FROM pedidos_compra", Long.class);

        jdbcTemplate.update("""
            INSERT INTO itens_pedido_compra (pedido_id, produto_id, quantidade)
            VALUES (?, ?, ?)
        """, pedidoId, req.getProdutoId(), req.getQuantidade());

        String produtoNome = jdbcTemplate.queryForObject("SELECT nome FROM produtos WHERE id = ?", String.class, req.getProdutoId());
        String filialNome = jdbcTemplate.queryForObject("SELECT nome FROM filiais WHERE id = ?", String.class, req.getFilialId());

        return new PedidoCompraResponse(pedidoId, req.getProdutoId(), produtoNome, req.getQuantidade(), req.getFilialId(), filialNome, solicitante, "Hoje", "aberto");
    }
}
