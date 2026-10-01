package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.AjusteEstoqueRequest;
import com.nicoly.LumeEstoque.dto.AlertasResponse;
import com.nicoly.LumeEstoque.dto.EstoqueResponse;
import com.nicoly.LumeEstoque.model.Usuario;
import com.nicoly.LumeEstoque.service.EstoqueService;
import com.nicoly.LumeEstoque.service.SecurityService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/estoque")
@CrossOrigin(origins = "*")
public class EstoqueController {

    private final EstoqueService estoqueService;
    private final SecurityService securityService;

    public EstoqueController(EstoqueService estoqueService, SecurityService securityService) {
        this.estoqueService = estoqueService;
        this.securityService = securityService;
    }

    @GetMapping
    public ResponseEntity<?> listar(
            @RequestHeader(value = "X-User-Email", required = false) String userEmail,
            @RequestHeader(value = "X-User-Role", required = false) String userRole,
            @RequestParam(required = false) Long filialId) {

        Usuario user = securityService.resolverUsuario(userEmail, userRole, null);
        if (user != null && "funcionario".equalsIgnoreCase(user.getTipo() != null ? user.getTipo() : user.getCargo())) {
            if (filialId == null) {
                filialId = user.getFilialId();
            } else if (user.getFilialId() != null && !user.getFilialId().equals(filialId)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(Map.of("message", "Acesso negado: Funcionários só podem visualizar estoque da própria filial."));
            }
        }

        return ResponseEntity.ok(estoqueService.listarEstoque(filialId));
    }

    @PostMapping("/ajustar")
    public ResponseEntity<?> ajustar(
            @RequestHeader(value = "X-User-Email", required = false) String userEmail,
            @RequestHeader(value = "X-User-Role", required = false) String userRole,
            @RequestBody AjusteEstoqueRequest request) {
        try {
            Usuario user = securityService.resolverUsuario(userEmail, userRole, request.getUsuario());
            securityService.validarAcessoFilial(user, request.getFilialId());

            EstoqueResponse response = estoqueService.ajustarEstoque(request);
            return ResponseEntity.ok(response);
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("message", e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Erro ao ajustar estoque: " + e.getMessage()));
        }
    }

    @GetMapping("/alertas")
    public ResponseEntity<?> alertas(
            @RequestHeader(value = "X-User-Email", required = false) String userEmail,
            @RequestHeader(value = "X-User-Role", required = false) String userRole,
            @RequestParam(required = false) Long filialId) {

        Usuario user = securityService.resolverUsuario(userEmail, userRole, null);
        if (user != null && "funcionario".equalsIgnoreCase(user.getTipo() != null ? user.getTipo() : user.getCargo())) {
            if (filialId == null) {
                filialId = user.getFilialId();
            } else if (user.getFilialId() != null && !user.getFilialId().equals(filialId)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(Map.of("message", "Acesso negado: Funcionários só podem visualizar alertas da própria filial."));
            }
        }

        return ResponseEntity.ok(estoqueService.listarAlertas(filialId));
    }
}
