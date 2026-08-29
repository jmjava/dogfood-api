package com.jmjava.dogfood.api;

import com.jmjava.dogfood.service.OrderService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orders;

    public OrderController(OrderService orders) {
        this.orders = orders;
    }

    @GetMapping
    public List<OrderStatusDto> byEmail(@RequestParam String email) {
        return orders.findByEmail(email).stream()
                .map(order -> new OrderStatusDto(order.id(), order.customerEmail(), order.status()))
                .toList();
    }

    @ExceptionHandler(OrderService.InvalidEmailException.class)
    public ResponseEntity<Void> invalidEmail() {
        return ResponseEntity.badRequest().build();
    }
}
