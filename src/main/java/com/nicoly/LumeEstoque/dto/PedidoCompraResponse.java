package com.nicoly.LumeEstoque.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class PedidoCompraResponse {
    private Long id;

    @JsonProperty("produto_id")
    private Long produtoId;

    private String produtoNome;

    private Integer quantidade;

    @JsonProperty("filial_id")
    private Long filialId;

    private String filialNome;
    private String solicitante;
    private String data;
    private String status;

    public PedidoCompraResponse() {}

    public PedidoCompraResponse(Long id, Long produtoId, String produtoNome, Integer quantidade, Long filialId, String filialNome, String solicitante, String data, String status) {
        this.id = id;
        this.produtoId = produtoId;
        this.produtoNome = produtoNome;
        this.quantidade = quantidade;
        this.filialId = filialId;
        this.filialNome = filialNome;
        this.solicitante = solicitante;
        this.data = data;
        this.status = status;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getProdutoId() { return produtoId; }
    public void setProdutoId(Long produtoId) { this.produtoId = produtoId; }

    public String getProdutoNome() { return produtoNome; }
    public void setProdutoNome(String produtoNome) { this.produtoNome = produtoNome; }

    public Integer getQuantidade() { return quantidade; }
    public void setQuantidade(Integer quantidade) { this.quantidade = quantidade; }

    public Long getFilialId() { return filialId; }
    public void setFilialId(Long filialId) { this.filialId = filialId; }

    public String getFilialNome() { return filialNome; }
    public void setFilialNome(String filialNome) { this.filialNome = filialNome; }

    public String getSolicitante() { return solicitante; }
    public void setSolicitante(String solicitante) { this.solicitante = solicitante; }

    public String getData() { return data; }
    public void setData(String data) { this.data = data; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}
