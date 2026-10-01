package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.DashboardResponse;
import com.nicoly.LumeEstoque.service.DashboardService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/dashboard")
@CrossOrigin(origins = "*")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping
    public ResponseEntity<DashboardResponse> obterResumo(@RequestParam(required = false) Long filialId) {
        return ResponseEntity.ok(dashboardService.obterResumo(filialId));
    }
}
