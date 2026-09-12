package com.kinhdoanh.luonweb.service;

import com.kinhdoanh.luonweb.entity.CartItem;
import com.kinhdoanh.luonweb.entity.Product;
import com.kinhdoanh.luonweb.entity.User;
import com.kinhdoanh.luonweb.repository.CartItemRepository;
import com.kinhdoanh.luonweb.repository.ProductRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class CartServiceTest {

    @Mock
    private CartItemRepository cartItemRepository;

    @Mock
    private ProductRepository productRepository;

    @InjectMocks
    private CartService cartService;

    private User user;
    private Product product1;
    private Product product2;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);

        product1 = new Product();
        product1.setId(1L);
        product1.setPrice(new BigDecimal("100000"));

        product2 = new Product();
        product2.setId(2L);
        product2.setPrice(new BigDecimal("50000"));
    }

    @Test
    void testGetCartTotal() {
        CartItem item1 = new CartItem();
        item1.setProduct(product1);
        item1.setQuantity(2); // 200,000

        CartItem item2 = new CartItem();
        item2.setProduct(product2);
        item2.setQuantity(3); // 150,000

        when(cartItemRepository.findByUser(user)).thenReturn(Arrays.asList(item1, item2));

        BigDecimal total = cartService.getCartTotal(user);
        
        assertEquals(new BigDecimal("350000"), total);
    }

    @Test
    void testAddToCart_ProductNotFound() {
        when(productRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(IllegalArgumentException.class, () -> {
            cartService.addToCart(user, 99L, 1);
        });
    }

    @Test
    void testAddToCart_NewItem() {
        when(productRepository.findById(1L)).thenReturn(Optional.of(product1));
        when(cartItemRepository.findByUserAndProduct(user, product1)).thenReturn(Optional.empty());

        cartService.addToCart(user, 1L, 2);

        verify(cartItemRepository, times(1)).save(any(CartItem.class));
    }
}
