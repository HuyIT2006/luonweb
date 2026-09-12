package com.kinhdoanh.luonweb.service;

import com.kinhdoanh.luonweb.entity.Order;
import com.kinhdoanh.luonweb.entity.Product;
import com.kinhdoanh.luonweb.entity.User;
import com.kinhdoanh.luonweb.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.LinkedHashMap;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final UserRepository userRepository;
    private final ProductRepository productRepository;
    private final OrderRepository orderRepository;
    private final CategoryRepository categoryRepository;

    public long getTotalUsers() {
        return userRepository.count();
    }

    public long getTotalProducts() {
        return productRepository.count();
    }

    public long getTotalOrders() {
        return orderRepository.count();
    }

    public long getTotalCategories() {
        return categoryRepository.count();
    }

    public BigDecimal getTotalRevenue() {
        List<Order> paidOrders = orderRepository.findAll().stream()
                .filter(o -> o.getPaymentStatus() == Order.PaymentStatus.PAID)
                .toList();
        return paidOrders.stream()
                .map(Order::getTotalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    public long getPendingOrders() {
        return orderRepository.findAll().stream()
                .filter(o -> o.getStatus() == Order.OrderStatus.PENDING)
                .count();
    }

    public Map<String, Long> getOrdersByStatus() {
        Map<String, Long> statusMap = new LinkedHashMap<>();
        for (Order.OrderStatus status : Order.OrderStatus.values()) {
            long count = orderRepository.findAll().stream()
                    .filter(o -> o.getStatus() == status)
                    .count();
            statusMap.put(status.name(), count);
        }
        return statusMap;
    }

    public List<Order> getRecentOrders(int limit) {
        List<Order> all = orderRepository.findAll();
        all.sort((a, b) -> b.getCreatedAt().compareTo(a.getCreatedAt()));
        return all.stream().limit(limit).toList();
    }

    // Product CRUD
    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    public Product getProductById(Long id) {
        return productRepository.findById(id).orElse(null);
    }

    @Transactional
    public Product saveProduct(Product product) {
        return productRepository.save(product);
    }

    @Transactional
    public void deleteProduct(Long id) {
        productRepository.deleteById(id);
    }

    // User management
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    @Transactional
    public void toggleUserEnabled(Long userId) {
        userRepository.findById(userId).ifPresent(user -> {
            user.setEnabled(!user.isEnabled());
            userRepository.save(user);
        });
    }

    @Transactional
    public void changeUserRole(Long userId, User.Role role) {
        userRepository.findById(userId).ifPresent(user -> {
            user.setRole(role);
            userRepository.save(user);
        });
    }

    // Order management
    public List<Order> getAllOrders() {
        List<Order> orders = orderRepository.findAll();
        orders.sort((a, b) -> b.getCreatedAt().compareTo(a.getCreatedAt()));
        return orders;
    }

    @Transactional
    public void updateOrderStatus(Long orderId, Order.OrderStatus status) {
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setStatus(status);
            orderRepository.save(order);
        });
    }

    @Transactional
    public void updatePaymentStatus(Long orderId, Order.PaymentStatus status) {
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setPaymentStatus(status);
            orderRepository.save(order);
        });
    }
}
