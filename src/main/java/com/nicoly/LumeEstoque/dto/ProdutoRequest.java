package com.nicoly.LumeEstoque.dto;

public class ProdutoRequest {
    private String nome;
    private String sku;
    private String codigo;
    private String descricao;
    private String categoria;
    private String unidadeMedida;
    private Integer qtdMinima;
    private Integer qtdInicial;
    private Integer qtd_minima;
    private Integer qtd_inicial;

    public ProdutoRequest() {}

    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }

    public String getSku() { return sku != null ? sku : codigo; }
    public void setSku(String sku) { this.sku = sku; }

    public String getCodigo() { return codigo != null ? codigo : sku; }
    public void setCodigo(String codigo) { this.codigo = codigo; }

    public String getDescricao() { return descricao; }
    public void setDescricao(String descricao) { this.descricao = descricao; }

    public String getCategoria() { return categoria; }
    public void setCategoria(String categoria) { this.categoria = categoria; }

    public String getUnidadeMedida() { return unidadeMedida; }
    public void setUnidadeMedida(String unidadeMedida) { this.unidadeMedida = unidadeMedida; }

    public Integer getQtdMinima() {
        if (qtdMinima != null) return qtdMinima;
        if (qtd_minima != null) return qtd_minima;
        return 10;
    }
    public void setQtdMinima(Integer qtdMinima) { this.qtdMinima = qtdMinima; }
    public void setQtd_minima(Integer qtd_minima) { this.qtd_minima = qtd_minima; }

    public Integer getQtdInicial() {
        if (qtdInicial != null) return qtdInicial;
        if (qtd_inicial != null) return qtd_inicial;
        return 0;
    }
    public void setQtdInicial(Integer qtdInicial) { this.qtdInicial = qtdInicial; }
    public void setQtd_inicial(Integer qtd_inicial) { this.qtd_inicial = qtd_inicial; }
}
