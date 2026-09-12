package com.kinhdoanh.luonweb.controller;

import com.kinhdoanh.luonweb.entity.Order;
import com.kinhdoanh.luonweb.entity.User;
import com.kinhdoanh.luonweb.repository.OrderRepository;
import com.kinhdoanh.luonweb.service.CartService;
import com.kinhdoanh.luonweb.service.OrderService;
import com.kinhdoanh.luonweb.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.math.BigDecimal;
import java.util.Map;

@Controller
@RequestMapping("/order")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;
    private final CartService cartService;
    private final UserService userService;
    private final OrderRepository orderRepository;

    private User getAuthenticatedUser(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return null;
        }
        return userService.findByEmail(authentication.getName()).orElse(null);
    }

    @GetMapping("/checkout")
    public String checkout(Model model, Authentication authentication) {
        User user = getAuthenticatedUser(authentication);
        if (user == null) {
            return "redirect:/login";
        }
        if (cartService.getCartItems(user).isEmpty()) {
            return "redirect:/cart";
        }
        
        BigDecimal totalAmount = cartService.getCartTotal(user);
        model.addAttribute("total", totalAmount);
        model.addAttribute("user", user);
        return "checkout";
    }

    @PostMapping("/submit")
    public String submitOrder(@RequestParam("fullName") String fullName,
                              @RequestParam("phone") String phone,
                              @RequestParam("address") String address,
                              @RequestParam("paymentMethod") String paymentMethod,
                              HttpServletRequest request,
                              Authentication authentication,
                              RedirectAttributes redirectAttributes) {
        User user = getAuthenticatedUser(authentication);
        if (user == null) {
            return "redirect:/login";
        }

        try {
            Order.PaymentMethod method = Order.PaymentMethod.valueOf(paymentMethod.toUpperCase());
            Order order = orderService.createOrder(user, fullName, phone, address, method);

            if (method == Order.PaymentMethod.VNPAY) {
                String ipAddress = request.getRemoteAddr();
                String paymentUrl = orderService.createVNPayUrl(order, ipAddress);
                return "redirect:" + paymentUrl;
            }

            return "redirect:/order/success?id=" + order.getId();
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("error", "Có lỗi xảy ra: " + e.getMessage());
            return "redirect:/order/checkout";
        }
    }

    @GetMapping("/vnpay-return")
    public String vnpayReturn(@RequestParam Map<String, String> queryParams, Model model) {
        boolean success = orderService.processVNPayReturn(queryParams);
        
        String txnRef = queryParams.get("vnp_TxnRef");
        Long orderId = null;
        if (txnRef != null && txnRef.contains("_")) {
            orderId = Long.parseLong(txnRef.split("_")[0]);
        }

        if (success) {
            return "redirect:/order/success?id=" + orderId;
        } else {
            model.addAttribute("error", "Thanh toán thất bại hoặc đã bị hủy.");
            return "order-failed";
        }
    }

    @GetMapping("/success")
    public String orderSuccess(@RequestParam(value = "id", required = false) Long orderId, 
                               Model model, Authentication authentication) {
        User user = getAuthenticatedUser(authentication);
        if (user == null) {
            return "redirect:/login";
        }
        
        if (orderId != null) {
            Order order = orderRepository.findById(orderId).orElse(null);
            if (order != null && order.getUser().getId().equals(user.getId())) {
                model.addAttribute("order", order);
            }
        }
        
        return "order-success";
    }
}
