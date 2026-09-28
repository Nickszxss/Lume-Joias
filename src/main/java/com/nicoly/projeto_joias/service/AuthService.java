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
        if (request == null || request.getEmail() == null || request.getEmail().isBlank()
                || request.getSenha() == null || request.getSenha().isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Acesso negado");
        }

        String email = request.getEmail().trim();
        Optional<Usuario> userOpt = usuarioRepository.findByEmailIgnoreCase(email);

        if (userOpt.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Acesso negado");
        }

        Usuario usuario = userOpt.get();

        // 1. Validar Senha
        if (!PasswordUtils.matches(request.getSenha(), usuario.getSenha())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Acesso negado");
        }

        // 2. Validar Nome se fornecido
        if (request.getNome() != null && !request.getNome().isBlank()) {
            if (!request.getNome().trim().equalsIgnoreCase(usuario.getNome().trim())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Acesso negado");
            }
        }

        // 3. Validar Cargo / Tipo se fornecido
        String cargoRequisitado = request.getCargo() != null && !request.getCargo().isBlank()
                ? request.getCargo()
                : request.getTipo();

        if (cargoRequisitado != null && !cargoRequisitado.isBlank()) {
            if (!cargoRequisitado.trim().equalsIgnoreCase(usuario.getCargo().trim())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Acesso negado");
            }
        }

        return new LoginResponse(
                usuario.getId(),
                usuario.getNome(),
                usuario.getEmail(),
                usuario.getCargo(),
                usuario.getFilialId(),
                "Login autorizado"
        );
    }
}
