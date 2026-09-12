package com.kinhdoanh.luonweb.config;

import com.kinhdoanh.luonweb.entity.Category;
import com.kinhdoanh.luonweb.entity.Product;
import com.kinhdoanh.luonweb.entity.User;
import com.kinhdoanh.luonweb.repository.CategoryRepository;
import com.kinhdoanh.luonweb.repository.ProductRepository;
import com.kinhdoanh.luonweb.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Arrays;

@Component
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {

    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        if (categoryRepository.count() == 0) {
            Category catTuoiSong = Category.builder().name("Lươn tươi sống").slug("tuoi-song").iconClass("T").build();
            Category catCheBien = Category.builder().name("Lươn chế biến").slug("che-bien").iconClass("C").build();
            Category catKhoRim = Category.builder().name("Lươn khô/rim").slug("kho-rim").iconClass("K").build();
            Category catChaLuon = Category.builder().name("Chả lươn").slug("cha-luon").iconClass("L").build();
            Category catGiaVi = Category.builder().name("Gia vị lẩu").slug("gia-vi").iconClass("G").build();

            categoryRepository.saveAll(Arrays.asList(catTuoiSong, catCheBien, catKhoRim, catChaLuon, catGiaVi));

            if (productRepository.count() == 0) {
                Product p1 = Product.builder()
                        .name("Lươn đồng tươi sống")
                        .price(new BigDecimal("180000"))
                        .description("Lươn đồng loại 1, được làm sạch và cắt khúc sẵn, đóng gói hút chân không an toàn.")
                        .featured(true)
                        .category(catTuoiSong)
                        .imageUrl("/images/default-luon.jpg")
                        .build();

                Product p2 = Product.builder()
                        .name("Chả lươn cuốn lá lốt")
                        .price(new BigDecimal("95000"))
                        .description("Chả lươn đậm đà, thơm mùi lá lốt, có thể chiên hoặc nướng.")
                        .featured(true)
                        .category(catChaLuon)
                        .imageUrl("/images/default-luon.jpg")
                        .build();

                Product p3 = Product.builder()
                        .name("Lươn um nghệ")
                        .price(new BigDecimal("120000"))
                        .description("Lươn um nghệ thơm lừng, vàng ươm, chuẩn vị miền Trung.")
                        .featured(true)
                        .category(catCheBien)
                        .imageUrl("/images/default-luon.jpg")
                        .build();

                Product p4 = Product.builder()
                        .name("Lươn khô rim mặn ngọt")
                        .price(new BigDecimal("150000"))
                        .description("Lươn sấy khô rim mặn ngọt, ăn liền kèm cơm nóng tuyệt ngon.")
                        .featured(true)
                        .category(catKhoRim)
                        .imageUrl("/images/default-luon.jpg")
                        .build();
                        
                Product p5 = Product.builder()
                        .name("Lươn ướp sa tế")
                        .price(new BigDecimal("110000"))
                        .description("Lươn tươi ướp sẵn sa tế cay nồng, thích hợp nướng hoặc xào.")
                        .featured(false)
                        .category(catCheBien)
                        .imageUrl("/images/default-luon.jpg")
                        .build();

                productRepository.saveAll(Arrays.asList(p1, p2, p3, p4, p5));
            }
        }

        // Create admin user if not exists
        if (!userRepository.existsByEmail("admin@luonviet.vn")) {
            User admin = User.builder()
                    .fullName("Admin Lươn Việt")
                    .email("admin@luonviet.vn")
                    .password(passwordEncoder.encode("admin123"))
                    .role(User.Role.ADMIN)
                    .provider(User.AuthProvider.LOCAL)
                    .enabled(true)
                    .build();
            userRepository.save(admin);
        }
    }
}
