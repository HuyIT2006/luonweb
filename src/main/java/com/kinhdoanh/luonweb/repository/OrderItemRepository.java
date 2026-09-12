package com.kinhdoanh.luonweb.repository;

import com.kinhdoanh.luonweb.entity.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {
}
