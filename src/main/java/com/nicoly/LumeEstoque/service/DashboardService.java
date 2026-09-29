package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.AlertasResponse;
import com.nicoly.LumeEstoque.dto.DashboardResponse;
import com.nicoly.LumeEstoque.dto.EstoqueResponse;
import com.nicoly.LumeEstoque.dto.ProdutoResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
public class DashboardService {

    private final JdbcTemplate jdbcTemplate;
    private final EstoqueService estoqueService;
    private final ProdutoService produtoService;

    public DashboardService(JdbcTemplate jdbcTemplate, EstoqueService estoqueService, ProdutoService produtoService) {
        this.jdbcTemplate = jdbcTemplate;
        this.estoqueService = estoqueService;
        this.produtoService = produtoService;
    }

    public DashboardResponse obterResumo(Long filialId) {
        List<EstoqueResponse> estoques = estoqueService.listarEstoque(filialId);
        List<ProdutoResponse> produtos = produtoService.listarTodos();
        AlertasResponse alertasRes = estoqueService.listarAlertas(filialId);

        int totalItens = 0;
        for (EstoqueResponse e : estoques) {
            totalItens += e.getQuantidade();
        }

        Integer totalTransfPendentes = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM transferencias WHERE status::text IN ('solicitada', 'pendente')", Integer.class
        );
        if (totalTransfPendentes == null) totalTransfPendentes = 0;

        List<Map<String, Object>> estoquePorFilial = new ArrayList<>();
        List<Map<String, Object>> filiais = jdbcTemplate.queryForList("SELECT id, nome FROM filiais ORDER BY id");

        for (Map<String, Object> f : filiais) {
            Long fId = ((Number) f.get("id")).longValue();
            String fNome = (String) f.get("nome");

            Integer totalFilial = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(quantidade), 0) FROM estoques WHERE filial_id = ?",
                Integer.class, fId
            );

            Map<String, Object> map = new HashMap<>();
            map.put("nome", fNome.replace("Filial ", ""));
            map.put("total", totalFilial != null ? totalFilial : 0);
            estoquePorFilial.add(map);
        }

        // Consultar movimentações reais dos últimos 7 dias no Supabase
        List<String> labels = new ArrayList<>();
        List<Integer> entradas = new ArrayList<>();
        List<Integer> saidas = new ArrayList<>();

        LocalDate hoje = LocalDate.now();
        DateTimeFormatter sqlDateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");

        for (int i = 6; i >= 0; i--) {
            LocalDate dia = hoje.minusDays(i);
            String diaSql = dia.format(sqlDateFormatter);
            String labelDia = dia.getDayOfWeek().getDisplayName(TextStyle.SHORT, new Locale("pt", "BR"));

            labels.add(labelDia);

            String whereFilial = filialId != null ? " AND filial_id = " + filialId : "";

            Integer totalEntrada = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(quantidade), 0) FROM movimentacoes WHERE tipo::text = 'entrada' AND DATE(created_at) = ?::date" + whereFilial,
                Integer.class, diaSql
            );

            Integer totalSaida = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(quantidade), 0) FROM movimentacoes WHERE tipo::text = 'saida' AND DATE(created_at) = ?::date" + whereFilial,
                Integer.class, diaSql
            );

            entradas.add(totalEntrada != null ? totalEntrada : 0);
            saidas.add(totalSaida != null ? totalSaida : 0);
        }

        Map<String, Object> movSemana = new HashMap<>();
        movSemana.put("labels", labels);
        movSemana.put("entradas", entradas);
        movSemana.put("saidas", saidas);

        DashboardResponse resp = new DashboardResponse();
        resp.setTotalItens(totalItens);
        resp.setTotalProdutos(produtos.size());
        resp.setTotalBaixo(alertasRes.getTotalBaixo());
        resp.setTotalZerado(alertasRes.getTotalZerado());
        resp.setTotalTransferenciasPendentes(totalTransfPendentes);
        resp.setEstoquePorFilial(estoquePorFilial);
        resp.setMovimentacoesSemana(movSemana);
        resp.setAlertas(alertasRes.getItens());
        resp.setEstoques(estoques);
        resp.setProdutos(produtos);

        return resp;
    }
}
