package com.nicoly.projeto_joias.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class LoginResponse {

    private Long id;
    private String nome;
    private String email;
    private String cargo;
    private String tipo;
    private Long filialId;
    @JsonProperty("filial_id")
    private Long filial_id;
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
        this.filial_id = filialId;
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
        return tipo != null ? tipo : cargo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
        if (this.cargo == null) {
            this.cargo = tipo;
        }
    }

    public Long getFilialId() {
        return filialId;
    }

    public void setFilialId(Long filialId) {
        this.filialId = filialId;
        this.filial_id = filialId;
    }

    public Long getFilial_id() {
        return filial_id != null ? filial_id : filialId;
    }

    public void setFilial_id(Long filial_id) {
        this.filial_id = filial_id;
        if (this.filialId == null) {
            this.filialId = filial_id;
        }
    }

    public String getMensagem() {
        return mensagem;
    }

    public void setMensagem(String mensagem) {
        this.mensagem = mensagem;
    }
}
