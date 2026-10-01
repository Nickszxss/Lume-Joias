package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.PedidoCompraRequest;
import com.nicoly.LumeEstoque.dto.PedidoCompraResponse;
import com.nicoly.LumeEstoque.service.PedidoService;
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

    public PedidoCompraController(PedidoService pedidoService) {
        this.pedidoService = pedidoService;
    }

    @GetMapping
    public ResponseEntity<List<PedidoCompraResponse>> listar() {
        return ResponseEntity.ok(pedidoService.listarTodos());
    }

    @PostMapping
    public ResponseEntity<?> criar(@RequestBody PedidoCompraRequest request,
                                   @RequestHeader(value = "X-User-Role", required = false) String roleHeader) {
        try {
            PedidoCompraResponse response = pedidoService.criar(request, roleHeader);
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
