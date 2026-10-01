package com.nicoly.LumeEstoque.controller;

import com.nicoly.LumeEstoque.dto.DashboardResponse;
import com.nicoly.LumeEstoque.model.Usuario;
import com.nicoly.LumeEstoque.service.DashboardService;
import com.nicoly.LumeEstoque.service.SecurityService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/dashboard")
@CrossOrigin(origins = "*")
public class DashboardController {

    private final DashboardService dashboardService;
    private final SecurityService securityService;

    public DashboardController(DashboardService dashboardService, SecurityService securityService) {
        this.dashboardService = dashboardService;
        this.securityService = securityService;
    }

    @GetMapping
    public ResponseEntity<?> obterResumo(
            @RequestHeader(value = "X-User-Email", required = false) String userEmail,
            @RequestHeader(value = "X-User-Role", required = false) String userRole,
            @RequestParam(required = false) Long filialId) {

        Usuario user = securityService.resolverUsuario(userEmail, userRole, null);
        if (user != null && "funcionario".equalsIgnoreCase(user.getTipo() != null ? user.getTipo() : user.getCargo())) {
            if (filialId == null) {
                filialId = user.getFilialId();
            } else if (user.getFilialId() != null && !user.getFilialId().equals(filialId)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(Map.of("message", "Acesso negado: Funcionários só podem visualizar dados de dashboard da própria filial."));
            }
        }

        return ResponseEntity.ok(dashboardService.obterResumo(filialId));
    }
}
