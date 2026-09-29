package com.nicoly.LumeEstoque.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class ProdutoResponse {
    private Long id;
    private String nome;
    private String sku;
    private String codigo;
    private String descricao;
    private String categoria;

    @JsonProperty("qtd_minima")
    private Integer qtdMinima;

    private Boolean ativo;

    public ProdutoResponse() {}

    public ProdutoResponse(Long id, String nome, String codigo, String descricao, String categoria, Integer qtdMinima, Boolean ativo) {
        this.id = id;
        this.nome = nome;
        this.sku = codigo;
        this.codigo = codigo;
        this.descricao = descricao;
        this.categoria = categoria != null ? categoria : "Joias";
        this.qtdMinima = qtdMinima;
        this.ativo = ativo;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }

    public String getSku() { return sku != null ? sku : codigo; }
    public void setSku(String sku) { this.sku = sku; this.codigo = sku; }

    public String getCodigo() { return codigo != null ? codigo : sku; }
    public void setCodigo(String codigo) { this.codigo = codigo; this.sku = codigo; }

    public String getDescricao() { return descricao; }
    public void setDescricao(String descricao) { this.descricao = descricao; }

    public String getCategoria() { return categoria; }
    public void setCategoria(String categoria) { this.categoria = categoria; }

    public Integer getQtdMinima() { return qtdMinima; }
    public void setQtdMinima(Integer qtdMinima) { this.qtdMinima = qtdMinima; }

    public Boolean getAtivo() { return ativo; }
    public void setAtivo(Boolean ativo) { this.ativo = ativo; }
}
