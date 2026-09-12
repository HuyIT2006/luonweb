package com.kinhdoanh.luonweb.controller;

import com.kinhdoanh.luonweb.entity.CartItem;
import com.kinhdoanh.luonweb.entity.User;
import com.kinhdoanh.luonweb.service.CartService;
import com.kinhdoanh.luonweb.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.math.BigDecimal;
import java.util.List;

@Controller
@RequestMapping("/cart")
@RequiredArgsConstructor
public class CartController {

    private final CartService cartService;
    private final UserService userService;

    private User getAuthenticatedUser(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return null;
        }
        return userService.findByEmail(authentication.getName()).orElse(null);
    }

    @GetMapping
    public String viewCart(Model model, Authentication authentication) {
        User user = getAuthenticatedUser(authentication);
        if (user == null) {
            return "redirect:/login";
        }

        List<CartItem> cartItems = cartService.getCartItems(user);
        BigDecimal total = cartService.getCartTotal(user);

        model.addAttribute("cartItems", cartItems);
        model.addAttribute("total", total);
        
        return "cart";
    }

    @PostMapping("/add")
    public String addToCart(@RequestParam("productId") Long productId,
                            @RequestParam(value = "quantity", defaultValue = "1") int quantity,
                            Authentication authentication,
                            RedirectAttributes redirectAttributes) {
        User user = getAuthenticatedUser(authentication);
        if (user == null) {
            redirectAttributes.addFlashAttribute("error", "Vui lòng đăng nhập để thêm sản phẩm vào giỏ hàng");
            return "redirect:/login";
        }

        cartService.addToCart(user, productId, quantity);
        redirectAttributes.addFlashAttribute("successMessage", "Đã thêm sản phẩm vào giỏ hàng");
        return "redirect:/cart";
    }

    @PostMapping("/update")
    public String updateQuantity(@RequestParam("cartItemId") Long cartItemId,
                                 @RequestParam("quantity") int quantity,
                                 Authentication authentication) {
        User user = getAuthenticatedUser(authentication);
        if (user != null) {
            cartService.updateQuantity(user, cartItemId, quantity);
        }
        return "redirect:/cart";
    }

    @PostMapping("/remove")
    public String removeFromCart(@RequestParam("cartItemId") Long cartItemId,
                                 Authentication authentication) {
        User user = getAuthenticatedUser(authentication);
        if (user != null) {
            cartService.removeFromCart(user, cartItemId);
        }
        return "redirect:/cart";
    }
}
