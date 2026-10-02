package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.LoginRequest;
import com.nicoly.LumeEstoque.dto.LoginResponse;
import com.nicoly.LumeEstoque.service.AuthService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping(value = {"/login", "/login/"})
    public ResponseEntity<?> login(@RequestBody(required = false) LoginRequest request) {
        if (request == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", "Nome, e-mail e senha são obrigatórios."));
        }

        try {
            LoginResponse response = authService.autenticar(request);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", e.getMessage()));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping(value = {"/login", "/login/"})
    public ResponseEntity<?> loginGet(
            @RequestParam(value = "nome", required = false) String nome,
            @RequestParam(value = "email", required = false) String email,
            @RequestParam(value = "senha", required = false) String senha) {
        if (nome != null && email != null && senha != null) {
            try {
                LoginResponse response = authService.autenticar(new LoginRequest(email, senha, nome));
                return ResponseEntity.ok(response);
            } catch (IllegalArgumentException e) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("message", e.getMessage()));
            } catch (RuntimeException e) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("message", e.getMessage()));
            }
        }
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("message", "Utilize o método POST para enviar o JSON com nome, e-mail e senha para realizar o login."));
    }
}
