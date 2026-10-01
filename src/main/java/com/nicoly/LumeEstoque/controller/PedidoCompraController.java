package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.PedidoCompraRequest;
import com.nicoly.LumeEstoque.dto.PedidoCompraResponse;
import com.nicoly.LumeEstoque.model.Usuario;
import com.nicoly.LumeEstoque.service.PedidoService;
import com.nicoly.LumeEstoque.service.SecurityService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/pedidos")
@CrossOrigin(origins = "*")
public class PedidoCompraController {

    private final PedidoService pedidoService;
    private final SecurityService securityService;

    public PedidoCompraController(PedidoService pedidoService, SecurityService securityService) {
        this.pedidoService = pedidoService;
        this.securityService = securityService;
    }

    @GetMapping
    public ResponseEntity<List<PedidoCompraResponse>> listar() {
        return ResponseEntity.ok(pedidoService.listarTodos());
    }

    @PostMapping
    public ResponseEntity<?> criar(@RequestBody PedidoCompraRequest request,
                                   @RequestHeader(value = "X-User-Email", required = false) String emailHeader,
                                   @RequestHeader(value = "X-User-Role", required = false) String roleHeader) {
        try {
            Usuario user = securityService.resolverUsuario(emailHeader, roleHeader, request.getSolicitante());
            securityService.validarGerente(user);

            String identificador = user != null ? user.getCargo() : roleHeader;
            PedidoCompraResponse response = pedidoService.criar(request, identificador);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("message", e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Erro ao criar pedido de compra: " + e.getMessage()));
        }
    }
}
