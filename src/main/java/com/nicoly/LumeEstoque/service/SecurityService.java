package com.nicoly.LumeEstoque.service;

import com.nicoly.LumeEstoque.model.Usuario;
import com.nicoly.LumeEstoque.repository.UsuarioRepository;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class SecurityService {

    private final UsuarioRepository usuarioRepository;

    public SecurityService(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    public Usuario resolverUsuario(String emailHeader, String roleHeader, String solicitanteNomeOuEmail) {
        if (emailHeader != null && !emailHeader.trim().isEmpty()) {
            Optional<Usuario> u = usuarioRepository.buscarPorEmail(emailHeader.trim());
            if (u.isPresent()) {
                return u.get();
            }
        }

        if (solicitanteNomeOuEmail != null && !solicitanteNomeOuEmail.trim().isEmpty()) {
            Optional<Usuario> u = usuarioRepository.buscarPorEmail(solicitanteNomeOuEmail.trim());
            if (u.isPresent()) {
                return u.get();
            }
        }

        // Se roleHeader for passado explicitamente quando email não for encontrado
        if (roleHeader != null && !roleHeader.trim().isEmpty()) {
            Usuario u = new Usuario();
            u.setCargo(roleHeader.trim());
            u.setTipo(roleHeader.trim());
            return u;
        }

        return null;
    }

    public void validarAcessoFilial(Usuario usuario, Long filialIdSolicitada) {
        if (usuario == null) return;
        String tipo = usuario.getTipo() != null ? usuario.getTipo() : usuario.getCargo();
        if ("funcionario".equalsIgnoreCase(tipo)) {
            if (usuario.getFilialId() != null && filialIdSolicitada != null && !usuario.getFilialId().equals(filialIdSolicitada)) {
                throw new SecurityException("Acesso negado: Funcionários só podem realizar operações em sua própria filial.");
            }
        }
    }

    public void validarOrigemTransferencia(Usuario usuario, Long origemId) {
        if (usuario == null) return;
        String tipo = usuario.getTipo() != null ? usuario.getTipo() : usuario.getCargo();
        if ("funcionario".equalsIgnoreCase(tipo)) {
            if (usuario.getFilialId() != null && origemId != null && !usuario.getFilialId().equals(origemId)) {
                throw new SecurityException("Acesso negado: Funcionários só podem originar transferências de sua própria filial.");
            }
        }
    }

    public void validarGerente(Usuario usuario) {
        if (usuario == null) return;
        String tipo = usuario.getTipo() != null ? usuario.getTipo() : usuario.getCargo();
        if ("funcionario".equalsIgnoreCase(tipo)) {
            throw new SecurityException("Apenas gerentes podem realizar pedidos de compra.");
        }
    }
}
