package com.nicoly.LumeEstoque.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class TransferenciaResponse {
    private Long id;

    @JsonProperty("produto_id")
    private Long produtoId;

    private String produtoNome;

    @JsonProperty("origem_id")
    private Long origemId;

    private String origemNome;

    @JsonProperty("destino_id")
    private Long destinoId;

    private String destinoNome;

    private Integer quantidade;
    private String solicitante;
    private String data;
    private String status;

    public TransferenciaResponse() {}

    public TransferenciaResponse(Long id, Long produtoId, String produtoNome, Long origemId, String origemNome, Long destinoId, String destinoNome, Integer quantidade, String solicitante, String data, String status) {
        this.id = id;
        this.produtoId = produtoId;
        this.produtoNome = produtoNome;
        this.origemId = origemId;
        this.origemNome = origemNome;
        this.destinoId = destinoId;
        this.destinoNome = destinoNome;
        this.quantidade = quantidade;
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

    public Long getOrigemId() { return origemId; }
    public void setOrigemId(Long origemId) { this.origemId = origemId; }

    public String getOrigemNome() { return origemNome; }
    public void setOrigemNome(String origemNome) { this.origemNome = origemNome; }

    public Long getDestinoId() { return destinoId; }
    public void setDestinoId(Long destinoId) { this.destinoId = destinoId; }

    public String getDestinoNome() { return destinoNome; }
    public void setDestinoNome(String destinoNome) { this.destinoNome = destinoNome; }

    public Integer getQuantidade() { return quantidade; }
    public void setQuantidade(Integer quantidade) { this.quantidade = quantidade; }

    public String getSolicitante() { return solicitante; }
    public void setSolicitante(String solicitante) { this.solicitante = solicitante; }

    public String getData() { return data; }
    public void setData(String data) { this.data = data; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}
