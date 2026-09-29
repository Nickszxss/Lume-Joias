package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.AjusteEstoqueRequest;
import com.nicoly.LumeEstoque.dto.AlertasResponse;
import com.nicoly.LumeEstoque.dto.EstoqueResponse;
import com.nicoly.LumeEstoque.service.EstoqueService;
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

    public EstoqueController(EstoqueService estoqueService) {
        this.estoqueService = estoqueService;
    }

    @GetMapping
    public ResponseEntity<List<EstoqueResponse>> listar(@RequestParam(required = false) Long filialId) {
        return ResponseEntity.ok(estoqueService.listarEstoque(filialId));
    }

    @PostMapping("/ajustar")
    public ResponseEntity<?> ajustar(@RequestBody AjusteEstoqueRequest request) {
        try {
            EstoqueResponse response = estoqueService.ajustarEstoque(request);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Erro ao ajustar estoque: " + e.getMessage()));
        }
    }

    @GetMapping("/alertas")
    public ResponseEntity<AlertasResponse> alertas(@RequestParam(required = false) Long filialId) {
        return ResponseEntity.ok(estoqueService.listarAlertas(filialId));
    }
}
