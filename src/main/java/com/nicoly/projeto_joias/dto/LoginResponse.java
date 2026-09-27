package com.nicoly.projeto_joias.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class LoginResponse {

    private Long id;
    private String nome;
    private String email;
    private String cargo;
    private String tipo;

    @JsonProperty("filial_id")
    private Long filialId;

    private String mensagem;

    public LoginResponse() {
    }

    public LoginResponse(Long id, String nome, String email, String cargo, Long filialId, String mensagem) {
        this.id = id;
        this.nome = nome;
        this.email = email;
        this.cargo = cargo;
        this.tipo = cargo;
        this.filialId = filialId;
        this.mensagem = mensagem;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getNome() {
        return nome;
    }

    public void setNome(String nome) {
        this.nome = nome;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getCargo() {
        return cargo;
    }

    public void setCargo(String cargo) {
        this.cargo = cargo;
        this.tipo = cargo;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public Long getFilialId() {
        return filialId;
    }

    public void setFilialId(Long filialId) {
        this.filialId = filialId;
    }

    public String getMensagem() {
        return mensagem;
    }

    public void setMensagem(String mensagem) {
        this.mensagem = mensagem;
    }
}
