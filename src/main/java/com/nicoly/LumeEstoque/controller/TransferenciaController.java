package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.TransferenciaRequest;
import com.nicoly.LumeEstoque.dto.TransferenciaResponse;
import com.nicoly.LumeEstoque.model.Usuario;
import com.nicoly.LumeEstoque.service.SecurityService;
import com.nicoly.LumeEstoque.service.TransferenciaService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/transferencias")
@CrossOrigin(origins = "*")
public class TransferenciaController {

    private final TransferenciaService transferenciaService;
    private final SecurityService securityService;

    public TransferenciaController(TransferenciaService transferenciaService, SecurityService securityService) {
        this.transferenciaService = transferenciaService;
        this.securityService = securityService;
    }

    @GetMapping
    public ResponseEntity<List<TransferenciaResponse>> listar() {
        return ResponseEntity.ok(transferenciaService.listarTodas());
    }

    @PostMapping
    public ResponseEntity<?> solicitar(
            @RequestHeader(value = "X-User-Email", required = false) String userEmail,
            @RequestHeader(value = "X-User-Role", required = false) String userRole,
            @RequestBody TransferenciaRequest request) {
        try {
            Usuario user = securityService.resolverUsuario(userEmail, userRole, request.getSolicitante());
            securityService.validarOrigemTransferencia(user, request.getOrigemId());

            TransferenciaResponse response = transferenciaService.solicitar(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("message", e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Erro ao solicitar transferência: " + e.getMessage()));
        }
    }

    @PatchMapping("/{id}/concluir")
    public ResponseEntity<?> concluir(@PathVariable Long id) {
        try {
            TransferenciaResponse response = transferenciaService.concluir(id);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Erro ao concluir transferência: " + e.getMessage()));
        }
    }
}
