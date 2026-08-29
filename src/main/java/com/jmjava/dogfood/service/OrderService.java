package com.jmjava.dogfood.service;

import com.jmjava.dogfood.domain.Order;
import com.jmjava.dogfood.persist.OrderRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.regex.Pattern;

@Service
public class OrderService {

    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");

    private final OrderRepository orders;

    public OrderService(OrderRepository orders) {
        this.orders = orders;
    }

    public List<Order> findByEmail(String email) {
        String normalized = (email == null) ? "" : email.trim();
        if (!EMAIL.matcher(normalized).matches()) {
            throw new InvalidEmailException(normalized);
        }
        return orders.findByCustomerEmail(normalized);
    }

    public static final class InvalidEmailException extends RuntimeException {
        public InvalidEmailException(String email) {
            super("invalid email: " + email);
        }
    }
}
