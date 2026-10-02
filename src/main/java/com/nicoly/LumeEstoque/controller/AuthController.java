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

    @PostMapping("/login")
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
}
