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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "spring.datasource.url=jdbc:h2:mem:projetojoiastest;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.jpa.database-platform=org.hibernate.dialect.H2Dialect"
})
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
        assertEquals("Login autorizado", response.getMensagem());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nome").value("Nicoly"))
                .andExpect(jsonPath("$.cargo").value("funcionario"))
                .andExpect(jsonPath("$.mensagem").value("Login autorizado"));
    }

    @Test
    @DisplayName("Teste 2 — Gerente: Login com credenciais válidas de gerente")
    void test2_GerenteLoginPermitido() throws Exception {
        LoginRequest req = new LoginRequest("Nicoly", "nicoly.grt@empresa.com", "160611", "gerente");

        LoginResponse response = authService.autenticar(req);
        assertNotNull(response);
        assertEquals("Nicoly", response.getNome());
        assertEquals("gerente", response.getCargo());
        assertEquals("Login autorizado", response.getMensagem());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nome").value("Nicoly"))
                .andExpect(jsonPath("$.cargo").value("gerente"))
                .andExpect(jsonPath("$.mensagem").value("Login autorizado"));
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
    @DisplayName("Teste 4 — E-mail incorreto / inexistente: Login recusado")
    void test4_EmailIncorretoRecusado() throws Exception {
        LoginRequest req = new LoginRequest("Nicoly", "usuario@empresa.com", "160611", "funcionario");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(req));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Teste 5 — Cargo incorreto: E-mail de funcionário com cargo gerente")
    void test5_CargoIncorretoRecusado() throws Exception {
        LoginRequest req = new LoginRequest("Nicoly", "nicoly.func@empresa.com", "160611", "gerente");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(req));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Teste 6 — Nome incorreto: Login recusado")
    void test6_NomeIncorretoRecusado() throws Exception {
        LoginRequest req = new LoginRequest("NomeErrado", "nicoly.func@empresa.com", "160611", "funcionario");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(req));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Teste 7 — Credenciais completamente incorretas: Login recusado")
    void test7_CredenciaisTotalmenteIncorretasRecusado() throws Exception {
        LoginRequest req = new LoginRequest("UsuarioFalso", "usuario@empresa.com", "senhaerrada", "funcionario");

        assertThrows(ResponseStatusException.class, () -> authService.autenticar(req));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }
}
