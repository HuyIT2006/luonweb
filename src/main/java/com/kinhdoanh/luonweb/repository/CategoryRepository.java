package com.kinhdoanh.luonweb.repository;

import com.kinhdoanh.luonweb.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategoryRepository extends JpaRepository<Category, Long> {
    Category findBySlug(String slug);
}
