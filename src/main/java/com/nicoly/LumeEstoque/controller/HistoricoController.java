package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.HistoricoResponse;
import com.nicoly.LumeEstoque.service.HistoricoService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/historico")
@CrossOrigin(origins = "*")
public class HistoricoController {

    private final HistoricoService historicoService;

    public HistoricoController(HistoricoService historicoService) {
        this.historicoService = historicoService;
    }

    @GetMapping
    public ResponseEntity<List<HistoricoResponse>> listar(
            @RequestParam(required = false) String tipo,
            @RequestParam(required = false) Long filialId) {
        return ResponseEntity.ok(historicoService.listar(tipo, filialId));
    }
}
