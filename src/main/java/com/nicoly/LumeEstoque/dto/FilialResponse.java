package com.nicoly.LumeEstoque.dto;

public class FilialResponse {
    private Long id;
    private String nome;
    private String endereco;
    private String cidade;
    private String estado;
    private Boolean ativa;

    public FilialResponse() {}

    public FilialResponse(Long id, String nome, String endereco, String cidade, String estado, Boolean ativa) {
        this.id = id;
        this.nome = nome;
        this.endereco = endereco;
        this.cidade = cidade;
        this.estado = estado;
        this.ativa = ativa;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }

    public String getEndereco() { return endereco; }
    public void setEndereco(String endereco) { this.endereco = endereco; }

    public String getCidade() { return cidade; }
    public void setCidade(String cidade) { this.cidade = cidade; }

    public String getEstado() { return estado; }
    public void setEstado(String estado) { this.estado = estado; }

    public Boolean getAtiva() { return ativa; }
    public void setAtiva(Boolean ativa) { this.ativa = ativa; }
}
