package com.nicoly.LumeEstoque.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class EstoqueResponse {
    @JsonProperty("produto_id")
    private Long produtoId;

    @JsonProperty("filial_id")
    private Long filialId;

    private Integer quantidade;

    @JsonProperty("qtd_minima")
    private Integer qtdMinima;

    private String status;
    private String produtoNome;
    private String filialNome;
    private String sku;

    public EstoqueResponse() {}

    public EstoqueResponse(Long produtoId, Long filialId, Integer quantidade, Integer qtdMinima, String status, String produtoNome, String filialNome, String sku) {
        this.produtoId = produtoId;
        this.filialId = filialId;
        this.quantidade = quantidade;
        this.qtdMinima = qtdMinima;
        this.status = status;
        this.produtoNome = produtoNome;
        this.filialNome = filialNome;
        this.sku = sku;
    }

    public Long getProdutoId() { return produtoId; }
    public void setProdutoId(Long produtoId) { this.produtoId = produtoId; }

    public Long getFilialId() { return filialId; }
    public void setFilialId(Long filialId) { this.filialId = filialId; }

    public Integer getQuantidade() { return quantidade; }
    public void setQuantidade(Integer quantidade) { this.quantidade = quantidade; }

    public Integer getQtdMinima() { return qtdMinima; }
    public void setQtdMinima(Integer qtdMinima) { this.qtdMinima = qtdMinima; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getProdutoNome() { return produtoNome; }
    public void setProdutoNome(String produtoNome) { this.produtoNome = produtoNome; }

    public String getFilialNome() { return filialNome; }
    public void setFilialNome(String filialNome) { this.filialNome = filialNome; }

    public String getSku() { return sku; }
    public void setSku(String sku) { this.sku = sku; }
}
