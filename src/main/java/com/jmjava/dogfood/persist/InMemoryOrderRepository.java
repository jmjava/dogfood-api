package com.jmjava.dogfood.persist;

import com.jmjava.dogfood.domain.Order;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@Repository
public class InMemoryOrderRepository implements OrderRepository {

    private final List<Order> orders = new CopyOnWriteArrayList<>(List.of(
            new Order("ord-100", "ops@example.com", "SHIPPED"),
            new Order("ord-101", "ops@example.com", "PENDING")
    ));

    @Override
    public List<Order> findByCustomerEmail(String customerEmail) {
        return orders.stream()
                .filter(order -> order.customerEmail().equalsIgnoreCase(customerEmail))
                .toList();
    }
}
