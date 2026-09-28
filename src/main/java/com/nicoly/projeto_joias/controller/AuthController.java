package com.nicoly.projeto_joias.controller;

import com.nicoly.projeto_joias.dto.LoginRequest;
import com.nicoly.projeto_joias.dto.LoginResponse;
import com.nicoly.projeto_joias.service.AuthService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@CrossOrigin(origins = "*")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping({"/api/auth/login", "/auth/login"})
    public ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) {
        LoginResponse response = authService.autenticar(request);
        return ResponseEntity.ok(response);
    }
}
