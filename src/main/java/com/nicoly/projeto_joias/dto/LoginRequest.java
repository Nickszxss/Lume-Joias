package com.nicoly.projeto_joias.dto;

public class LoginRequest {

    private String nome;
    private String email;
    private String senha;
    private String cargo;

    public LoginRequest() {
    }

    public LoginRequest(String email, String senha) {
        this.email = email;
        this.senha = senha;
    }

    public LoginRequest(String nome, String email, String senha, String cargo) {
        this.nome = nome;
        this.email = email;
        this.senha = senha;
        this.cargo = cargo;
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

    public String getSenha() {
        return senha;
    }

    public void setSenha(String senha) {
        this.senha = senha;
    }

    public String getCargo() {
        return cargo;
    }

    public void setCargo(String cargo) {
        this.cargo = cargo;
    }

    public String getTipo() {
        return cargo;
    }

    public void setTipo(String tipo) {
        if (this.cargo == null) {
            this.cargo = tipo;
        }
    }
}
