package com.nicoly.projeto_joias.service;

import com.nicoly.projeto_joias.dto.LoginRequest;
import com.nicoly.projeto_joias.dto.LoginResponse;
import com.nicoly.projeto_joias.model.Usuario;
import com.nicoly.projeto_joias.repository.UsuarioRepository;
import com.nicoly.projeto_joias.util.PasswordUtils;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;

    public AuthService(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    public LoginResponse autenticar(LoginRequest request) {
        if (request == null || request.getEmail() == null || request.getSenha() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "ACESSO NEGADO");
        }

        String email = request.getEmail().trim();
        Optional<Usuario> userOpt = usuarioRepository.findByEmail(email);

        if (userOpt.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "ACESSO NEGADO");
        }

        Usuario usuario = userOpt.get();

        // 1. Validar Nome
        if (request.getNome() != null && !request.getNome().isBlank()) {
            if (!request.getNome().trim().equalsIgnoreCase(usuario.getNome().trim())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "ACESSO NEGADO");
            }
        }

        // 2. Validar Cargo
        if (request.getCargo() != null && !request.getCargo().isBlank()) {
            if (!request.getCargo().trim().equalsIgnoreCase(usuario.getCargo().trim())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "ACESSO NEGADO");
            }
        }

        // 3. Validar Senha
        if (!PasswordUtils.matches(request.getSenha(), usuario.getSenha())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "ACESSO NEGADO");
        }

        return new LoginResponse(
                usuario.getId(),
                usuario.getNome(),
                usuario.getEmail(),
                usuario.getCargo(),
                usuario.getFilialId(),
                "ACESSO PERMITIDO"
        );
    }
}
