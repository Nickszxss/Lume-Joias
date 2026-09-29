package com.nicoly.LumeEstoque;

import com.nicoly.LumeEstoque.controller.AuthController;
import com.nicoly.LumeEstoque.dto.LoginRequest;
import com.nicoly.LumeEstoque.dto.LoginResponse;
import com.nicoly.LumeEstoque.service.AuthService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class AuthIntegrationTest {

    @Autowired
    private AuthController authController;

    @Autowired
    private AuthService authService;

    @Test
    @DisplayName("Login Funcionário Anderson Correto - ACESSO PERMITIDO")
    void loginFuncionarioAndersonCorreto() {
        LoginRequest request = new LoginRequest("anderson.func@empresa.com", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertTrue(response.getBody() instanceof LoginResponse);

        LoginResponse loginResponse = (LoginResponse) response.getBody();
        assertEquals("anderson.func@empresa.com", loginResponse.getEmail());
        assertEquals("Anderson", loginResponse.getNome());
        assertEquals("funcionario", loginResponse.getCargo());
        assertEquals("funcionario", loginResponse.getTipo());
    }

    @Test
    @DisplayName("Login Gerente Robson Correto - ACESSO PERMITIDO")
    void loginGerenteRobsonCorreto() {
        LoginRequest request = new LoginRequest("robson.grt@empresa.com", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertTrue(response.getBody() instanceof LoginResponse);

        LoginResponse loginResponse = (LoginResponse) response.getBody();
        assertEquals("robson.grt@empresa.com", loginResponse.getEmail());
        assertEquals("Robson", loginResponse.getNome());
        assertEquals("gerente", loginResponse.getCargo());
        assertEquals("gerente", loginResponse.getTipo());
    }

    @Test
    @DisplayName("Login Funcionária Isabella Correto - ACESSO PERMITIDO")
    void loginFuncionarioIsabellaCorreto() {
        LoginRequest request = new LoginRequest("isabella.func@empresa.com", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());

        LoginResponse loginResponse = (LoginResponse) response.getBody();
        assertEquals("isabella.func@empresa.com", loginResponse.getEmail());
        assertEquals("Isabella", loginResponse.getNome());
        assertEquals("funcionario", loginResponse.getCargo());
    }

    @Test
    @DisplayName("Login Gerente Manuella Correto - ACESSO PERMITIDO")
    void loginGerenteManuellaCorreto() {
        LoginRequest request = new LoginRequest("manuella.grt@empresa.com", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());

        LoginResponse loginResponse = (LoginResponse) response.getBody();
        assertEquals("manuella.grt@empresa.com", loginResponse.getEmail());
        assertEquals("Manuella", loginResponse.getNome());
        assertEquals("gerente", loginResponse.getCargo());
    }

    @Test
    @DisplayName("Teste 1 - Senha incorreta do funcionário - ACESSO NEGADO")
    void teste1SenhaIncorretaFuncionario() {
        LoginRequest request = new LoginRequest("anderson.func@empresa.com", "senhaIncorreta", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 2 - Senha incorreta do gerente - ACESSO NEGADO")
    void teste2SenhaIncorretaGerente() {
        LoginRequest request = new LoginRequest("robson.grt@empresa.com", "senhaIncorreta", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 3 - Email inexistente - ACESSO NEGADO")
    void teste3EmailInexistente() {
        LoginRequest request = new LoginRequest("inexistente@empresa.com", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 4 - Email parcialmente incorreto - ACESSO NEGADO")
    void teste4EmailParcialmenteIncorreto() {
        LoginRequest request = new LoginRequest("anderson.func@empresa.co", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 5 - Email vazio - ACESSO NEGADO")
    void teste5EmailVazio() {
        LoginRequest request = new LoginRequest("", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 6 - Senha vazia - ACESSO NEGADO")
    void teste6SenhaVazia() {
        LoginRequest request = new LoginRequest("anderson.func@empresa.com", "", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 7 - Ambos vazios - ACESSO NEGADO")
    void teste7AmbosVazios() {
        LoginRequest request = new LoginRequest("", "", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 8 - Alterar um caractere da senha - ACESSO NEGADO")
    void teste8AlterarUmCaractereSenha() {
        LoginRequest request = new LoginRequest("anderson.func@empresa.com", "etec2026@Ds", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Teste 9 - Trocar usuário e manter senha - ACESSO NEGADO")
    void teste9TrocarUsuarioManterSenha() {
        LoginRequest request = new LoginRequest("email.inexistente@empresa.com", "etec2026@DS", null);
        ResponseEntity<?> response = authController.login(request);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    @DisplayName("Verificar separação de usuários e permissões do objeto retornado")
    void testSeparacaoUsuariosEInformacoes() {
        LoginResponse funcResp = authService.autenticar(new LoginRequest("anderson.func@empresa.com", "etec2026@DS", null));
        LoginResponse grtResp = authService.autenticar(new LoginRequest("robson.grt@empresa.com", "etec2026@DS", null));

        assertEquals("funcionario", funcResp.getCargo());
        assertEquals("gerente", grtResp.getCargo());

        assertNotEquals(funcResp.getEmail(), grtResp.getEmail());
    }
}
