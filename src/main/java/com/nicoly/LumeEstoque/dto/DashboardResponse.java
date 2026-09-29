package com.nicoly.LumeEstoque.dto;

import java.util.List;
import java.util.Map;

public class DashboardResponse {
    private Integer totalItens;
    private Integer totalProdutos;
    private Integer totalBaixo;
    private Integer totalZerado;
    private Integer totalTransferenciasPendentes;
    private List<Map<String, Object>> estoquePorFilial;
    private Map<String, Object> movimentacoesSemana;
    private List<EstoqueResponse> alertas;
    private List<EstoqueResponse> estoques;
    private List<ProdutoResponse> produtos;

    public DashboardResponse() {}

    public Integer getTotalItens() { return totalItens; }
    public void setTotalItens(Integer totalItens) { this.totalItens = totalItens; }

    public Integer getTotalProdutos() { return totalProdutos; }
    public void setTotalProdutos(Integer totalProdutos) { this.totalProdutos = totalProdutos; }

    public Integer getTotalBaixo() { return totalBaixo; }
    public void setTotalBaixo(Integer totalBaixo) { this.totalBaixo = totalBaixo; }

    public Integer getTotalZerado() { return totalZerado; }
    public void setTotalZerado(Integer totalZerado) { this.totalZerado = totalZerado; }

    public Integer getTotalTransferenciasPendentes() { return totalTransferenciasPendentes; }
    public void setTotalTransferenciasPendentes(Integer totalTransferenciasPendentes) { this.totalTransferenciasPendentes = totalTransferenciasPendentes; }

    public List<Map<String, Object>> getEstoquePorFilial() { return estoquePorFilial; }
    public void setEstoquePorFilial(List<Map<String, Object>> estoquePorFilial) { this.estoquePorFilial = estoquePorFilial; }

    public Map<String, Object> getMovimentacoesSemana() { return movimentacoesSemana; }
    public void setMovimentacoesSemana(Map<String, Object> movimentacoesSemana) { this.movimentacoesSemana = movimentacoesSemana; }

    public List<EstoqueResponse> getAlertas() { return alertas; }
    public void setAlertas(List<EstoqueResponse> alertas) { this.alertas = alertas; }

    public List<EstoqueResponse> getEstoques() { return estoques; }
    public void setEstoques(List<EstoqueResponse> estoques) { this.estoques = estoques; }

    public List<ProdutoResponse> getProdutos() { return produtos; }
    public void setProdutos(List<ProdutoResponse> produtos) { this.produtos = produtos; }
}
