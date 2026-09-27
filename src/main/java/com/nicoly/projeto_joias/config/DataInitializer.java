package com.nicoly.projeto_joias.config;

import com.nicoly.projeto_joias.model.Usuario;
import com.nicoly.projeto_joias.repository.UsuarioRepository;
import com.nicoly.projeto_joias.util.PasswordUtils;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class DataInitializer implements CommandLineRunner {

    private final UsuarioRepository usuarioRepository;

    public DataInitializer(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        // Primeiro cadastro — Funcionário
        if (usuarioRepository.findByEmail("nicoly.func@empresa.com").isEmpty()) {
            Usuario func = new Usuario(
                    "Nicoly",
                    "nicoly.func@empresa.com",
                    PasswordUtils.hashPassword("160611"),
                    "funcionario",
                    1L
            );
            usuarioRepository.save(func);
            System.out.println("Usuário Funcionário cadastrado no banco: nicoly.func@empresa.com");
        }

        // Primeiro cadastro — Gerente
        if (usuarioRepository.findByEmail("nicoly.grt@empresa.com").isEmpty()) {
            Usuario gerente = new Usuario(
                    "Nicoly",
                    "nicoly.grt@empresa.com",
                    PasswordUtils.hashPassword("160611"),
                    "gerente",
                    null
            );
            usuarioRepository.save(gerente);
            System.out.println("Usuário Gerente cadastrado no banco: nicoly.grt@empresa.com");
        }
    }
}
