package com.nicoly.projeto_joias;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nicoly.projeto_joias.dto.LoginRequest;
import com.nicoly.projeto_joias.dto.LoginResponse;
import com.nicoly.projeto_joias.service.AuthService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class AuthIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AuthService authService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    @DisplayName("Teste 1 — Funcionário: Login com credenciais válidas de funcionário")
    void test1_FuncionarioLoginPermitido() throws Exception {
        LoginRequest req = new LoginRequest("Nicoly", "nicoly.func@empresa.com", "160611", "funcionario");

        LoginResponse response = authService.autenticar(req);
        assertNotNull(response);
        assertEquals("Nicoly", response.getNome());
        assertEquals("funcionario", response.getCargo());
        assertEquals("ACESSO PERMITIDO", response.getMensagem());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nome").value("Nicoly"))
                .andExpect(jsonPath("$.cargo").value("funcionario"))
                .andExpect(jsonPath("$.mensagem").value("ACESSO PERMITIDO"));
    }

    @Test
    @DisplayName("Teste 2 — Gerente: Login com credenciais válidas de gerente")
    void test2_GerenteLoginPermitido() throws Exception {
        LoginRequest req = new LoginRequest("Nicoly", "nicoly.grt@empresa.com", "160611", "gerente");

        LoginResponse response = authService.autenticar(req);
        assertNotNull(response);
        assertEquals("Nicoly", response.getNome());
        assertEquals("gerente", response.getCargo());
        assertEquals("ACESSO PERMITIDO", response.getMensagem());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nome").value("Nicoly"))
                .andExpect(jsonPath("$.cargo").value("gerente"))
                .andExpect(jsonPath("$.mensagem").value("ACESSO PERMITIDO"));
    }

    @Test
    @DisplayName("Teste 3 — Senha incorreta: Login recusado")
    void test3_SenhaIncorretaRecusado() throws Exception {
        LoginRequest req = new LoginRequest("Nicoly", "nicoly.func@empresa.com", "senha_errada", "funcionario");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(req));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Teste 4 — E-mail incorreto: Login recusado")
    void test4_EmailIncorretoRecusado() throws Exception {
        LoginRequest req = new LoginRequest("Nicoly", "email.errado@empresa.com", "160611", "funcionario");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(req));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Teste 5 — Cargo incorreto: E-mail de funcionário com cargo gerente e vice-versa")
    void test5_CargoIncorretoRecusado() throws Exception {
        // E-mail funcionário selecionando gerente
        LoginRequest reqFuncComGerente = new LoginRequest("Nicoly", "nicoly.func@empresa.com", "160611", "gerente");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(reqFuncComGerente));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reqFuncComGerente)))
                .andExpect(status().isUnauthorized());

        // E-mail gerente selecionando funcionário
        LoginRequest reqGrtComFuncionario = new LoginRequest("Nicoly", "nicoly.grt@empresa.com", "160611", "funcionario");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(reqGrtComFuncionario));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reqGrtComFuncionario)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Teste 6 — Usuário inexistente: Login recusado")
    void test6_UsuarioInexistenteRecusado() throws Exception {
        LoginRequest req = new LoginRequest("UsuarioFalso", "falso@empresa.com", "999999", "funcionario");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(req));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }
}
