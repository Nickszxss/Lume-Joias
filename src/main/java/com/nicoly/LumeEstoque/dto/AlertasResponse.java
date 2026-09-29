package com.nicoly.LumeEstoque.dto;

import java.util.List;

public class AlertasResponse {
    private Integer totalBaixo;
    private Integer totalZerado;
    private List<EstoqueResponse> itens;

    public AlertasResponse() {}

    public AlertasResponse(Integer totalBaixo, Integer totalZerado, List<EstoqueResponse> itens) {
        this.totalBaixo = totalBaixo;
        this.totalZerado = totalZerado;
        this.itens = itens;
    }

    public Integer getTotalBaixo() { return totalBaixo; }
    public void setTotalBaixo(Integer totalBaixo) { this.totalBaixo = totalBaixo; }

    public Integer getTotalZerado() { return totalZerado; }
    public void setTotalZerado(Integer totalZerado) { this.totalZerado = totalZerado; }

    public List<EstoqueResponse> getItens() { return itens; }
    public void setItens(List<EstoqueResponse> itens) { this.itens = itens; }
}
