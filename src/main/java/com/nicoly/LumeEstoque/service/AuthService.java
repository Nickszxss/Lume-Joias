package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.dto.LoginRequest;
import com.nicoly.LumeEstoque.dto.LoginResponse;
import com.nicoly.LumeEstoque.model.Usuario;
import com.nicoly.LumeEstoque.repository.UsuarioRepository;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final BCryptPasswordEncoder passwordEncoder;

    public AuthService(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = new BCryptPasswordEncoder();
    }

    public LoginResponse autenticar(LoginRequest request) {
        if (request == null ||
            request.getNome() == null || request.getNome().trim().isEmpty() ||
            request.getEmail() == null || request.getEmail().trim().isEmpty() ||
            request.getSenha() == null || request.getSenha().trim().isEmpty()) {
            throw new IllegalArgumentException("Nome, e-mail e senha são obrigatórios.");
        }

        Optional<Usuario> usuarioOpt = usuarioRepository.buscarPorEmail(request.getEmail().trim());
        if (usuarioOpt.isEmpty()) {
            throw new RuntimeException("Credenciais inválidas.");
        }

        Usuario usuario = usuarioOpt.get();

        if (usuario.getNome() == null || !usuario.getNome().trim().equalsIgnoreCase(request.getNome().trim())) {
            throw new RuntimeException("Credenciais inválidas.");
        }

        boolean senhaValida = false;
        // Tenta BCrypt primeiro; fallback para texto plano se não for hash BCrypt
        if (usuario.getSenha() != null && (usuario.getSenha().startsWith("$2a$") || usuario.getSenha().startsWith("$2b$") || usuario.getSenha().startsWith("$2y$"))) {
            senhaValida = passwordEncoder.matches(request.getSenha(), usuario.getSenha());
        } else {
            senhaValida = usuario.getSenha() != null && usuario.getSenha().equals(request.getSenha());
        }

        if (!senhaValida) {
            throw new RuntimeException("Credenciais inválidas.");
        }

        String cargo = usuario.getCargo() != null ? usuario.getCargo() : usuario.getTipo();
        String tipo = usuario.getTipo() != null ? usuario.getTipo() : usuario.getCargo();

        return new LoginResponse(
            usuario.getId(),
            usuario.getNome(),
            usuario.getEmail(),
            cargo,
            tipo,
            usuario.getFilialId()
        );
    }
}
