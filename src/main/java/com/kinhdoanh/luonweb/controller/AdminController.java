package com.kinhdoanh.luonweb.controller;

import com.kinhdoanh.luonweb.entity.Order;
import com.kinhdoanh.luonweb.entity.Product;
import com.kinhdoanh.luonweb.entity.User;
import com.kinhdoanh.luonweb.repository.CategoryRepository;
import com.kinhdoanh.luonweb.service.AdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.math.BigDecimal;

@Controller
@RequestMapping("/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;
    private final CategoryRepository categoryRepository;

    @GetMapping
    public String dashboard(Model model) {
        model.addAttribute("totalUsers", adminService.getTotalUsers());
        model.addAttribute("totalProducts", adminService.getTotalProducts());
        model.addAttribute("totalOrders", adminService.getTotalOrders());
        model.addAttribute("totalRevenue", adminService.getTotalRevenue());
        model.addAttribute("pendingOrders", adminService.getPendingOrders());
        model.addAttribute("ordersByStatus", adminService.getOrdersByStatus());
        model.addAttribute("recentOrders", adminService.getRecentOrders(5));
        return "admin/dashboard";
    }

    // --- Products ---
    @GetMapping("/products")
    public String products(Model model) {
        model.addAttribute("products", adminService.getAllProducts());
        return "admin/products";
    }

    @GetMapping("/products/add")
    public String addProductForm(Model model) {
        model.addAttribute("product", new Product());
        model.addAttribute("categories", categoryRepository.findAll());
        return "admin/product-form";
    }

    @GetMapping("/products/edit/{id}")
    public String editProductForm(@PathVariable Long id, Model model) {
        Product product = adminService.getProductById(id);
        if (product == null) return "redirect:/admin/products";
        model.addAttribute("product", product);
        model.addAttribute("categories", categoryRepository.findAll());
        return "admin/product-form";
    }

    @PostMapping("/products/save")
    public String saveProduct(@ModelAttribute Product product,
                              @RequestParam("categoryId") Long categoryId,
                              RedirectAttributes ra) {
        categoryRepository.findById(categoryId).ifPresent(product::setCategory);
        adminService.saveProduct(product);
        ra.addFlashAttribute("success", "Lưu sản phẩm thành công!");
        return "redirect:/admin/products";
    }

    @PostMapping("/products/delete/{id}")
    public String deleteProduct(@PathVariable Long id, RedirectAttributes ra) {
        adminService.deleteProduct(id);
        ra.addFlashAttribute("success", "Đã xóa sản phẩm!");
        return "redirect:/admin/products";
    }

    // --- Orders ---
    @GetMapping("/orders")
    public String orders(Model model) {
        model.addAttribute("orders", adminService.getAllOrders());
        return "admin/orders";
    }

    @PostMapping("/orders/{id}/status")
    public String updateOrderStatus(@PathVariable Long id,
                                     @RequestParam("status") String status,
                                     RedirectAttributes ra) {
        adminService.updateOrderStatus(id, Order.OrderStatus.valueOf(status));
        ra.addFlashAttribute("success", "Cập nhật trạng thái đơn hàng thành công!");
        return "redirect:/admin/orders";
    }

    @PostMapping("/orders/{id}/payment")
    public String updatePaymentStatus(@PathVariable Long id,
                                       @RequestParam("paymentStatus") String paymentStatus,
                                       RedirectAttributes ra) {
        adminService.updatePaymentStatus(id, Order.PaymentStatus.valueOf(paymentStatus));
        ra.addFlashAttribute("success", "Cập nhật thanh toán thành công!");
        return "redirect:/admin/orders";
    }

    // --- Users ---
    @GetMapping("/users")
    public String users(Model model) {
        model.addAttribute("users", adminService.getAllUsers());
        return "admin/users";
    }

    @PostMapping("/users/{id}/toggle")
    public String toggleUser(@PathVariable Long id, RedirectAttributes ra) {
        adminService.toggleUserEnabled(id);
        ra.addFlashAttribute("success", "Cập nhật trạng thái người dùng!");
        return "redirect:/admin/users";
    }

    @PostMapping("/users/{id}/role")
    public String changeRole(@PathVariable Long id, @RequestParam("role") String role, RedirectAttributes ra) {
        adminService.changeUserRole(id, User.Role.valueOf(role));
        ra.addFlashAttribute("success", "Cập nhật quyền người dùng!");
        return "redirect:/admin/users";
    }
}
