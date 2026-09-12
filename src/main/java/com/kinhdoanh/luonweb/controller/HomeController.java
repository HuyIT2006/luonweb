package com.kinhdoanh.luonweb.controller;

import com.kinhdoanh.luonweb.repository.CategoryRepository;
import com.kinhdoanh.luonweb.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
@RequiredArgsConstructor
public class HomeController {

    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("categories", categoryRepository.findAll());
        model.addAttribute("featuredProducts", productRepository.findByFeaturedTrue());
        return "index"; // -> templates/index.html
    }
}