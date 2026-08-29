package com.jmjava.dogfood.persist;

import com.jmjava.dogfood.domain.Order;

import java.util.List;

public interface OrderRepository {

    List<Order> findByCustomerEmail(String customerEmail);
}
