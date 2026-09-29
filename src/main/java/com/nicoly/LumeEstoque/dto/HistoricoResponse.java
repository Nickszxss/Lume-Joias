package com.nicoly.LumeEstoque.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class HistoricoResponse {
    private Long id;
    private String data;

    @JsonProperty("produto_id")
    private Long produtoId;

    private String produtoNome;

    @JsonProperty("filial_id")
    private Long filialId;

    private String filialNome;
    private String tipo;
    private Integer anterior;
    private Integer nova;
    private String usuario;
    private String motivo;

    public HistoricoResponse() {}

    public HistoricoResponse(Long id, String data, Long produtoId, String produtoNome, Long filialId, String filialNome, String tipo, Integer anterior, Integer nova, String usuario, String motivo) {
        this.id = id;
        this.data = data;
        this.produtoId = produtoId;
        this.produtoNome = produtoNome;
        this.filialId = filialId;
        this.filialNome = filialNome;
        this.tipo = tipo;
        this.anterior = anterior;
        this.nova = nova;
        this.usuario = usuario;
        this.motivo = motivo;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getData() { return data; }
    public void setData(String data) { this.data = data; }

    public Long getProdutoId() { return produtoId; }
    public void setProdutoId(Long produtoId) { this.produtoId = produtoId; }

    public String getProdutoNome() { return produtoNome; }
    public void setProdutoNome(String produtoNome) { this.produtoNome = produtoNome; }

    public Long getFilialId() { return filialId; }
    public void setFilialId(Long filialId) { this.filialId = filialId; }

    public String getFilialNome() { return filialNome; }
    public void setFilialNome(String filialNome) { this.filialNome = filialNome; }

    public String getTipo() { return tipo; }
    public void setTipo(String tipo) { this.tipo = tipo; }

    public Integer getAnterior() { return anterior; }
    public void setAnterior(Integer anterior) { this.anterior = anterior; }

    public Integer getNova() { return nova; }
    public void setNova(Integer nova) { this.nova = nova; }

    public String getUsuario() { return usuario; }
    public void setUsuario(String usuario) { this.usuario = usuario; }

    public String getMotivo() { return motivo; }
    public void setMotivo(String motivo) { this.motivo = motivo; }
}
