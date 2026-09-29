package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.FilialResponse;
import com.nicoly.LumeEstoque.service.FilialService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/filiais")
@CrossOrigin(origins = "*")
public class FilialController {

    private final FilialService filialService;

    public FilialController(FilialService filialService) {
        this.filialService = filialService;
    }

    @GetMapping
    public ResponseEntity<List<FilialResponse>> listar() {
        return ResponseEntity.ok(filialService.listarTodas());
    }
}
