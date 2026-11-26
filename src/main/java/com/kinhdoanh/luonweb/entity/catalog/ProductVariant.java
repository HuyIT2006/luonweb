package com.kinhdoanh.luonweb.entity.catalog;

import com.kinhdoanh.luonweb.entity.enums.Unit;
import com.kinhdoanh.luonweb.entity.enums.VariantType;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(
    name = "product_variants",
    uniqueConstraints = @UniqueConstraint(name = "uk_variants_sku", columnNames = "sku"),
    indexes = {
        @Index(name = "idx_variants_product", columnList = "product_id, is_active"),
        @Index(name = "idx_variants_type", columnList = "variant_type, is_active"),
        @Index(name = "idx_variants_price", columnList = "price")
    }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@ToString(exclude = {"product", "comboComponents"})
public class ProductVariant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @EqualsAndHashCode.Include
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false, foreignKey = @ForeignKey(name = "fk_variants_product"))
    private Product product;

    @Column(nullable = false, length = 50)
    private String sku;

    @Column(nullable = false, length = 150)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "variant_type", nullable = false, length = 30)
    private VariantType variantType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Unit unit;

    @Column(name = "weight_grams", nullable = false)
    @Builder.Default
    private Integer weightGrams = 0;

    @Column(nullable = false, precision = 12, scale = 0)
    private BigDecimal price;

    @Column(name = "sale_price", precision = 12, scale = 0)
    private BigDecimal salePrice;

    @Column(name = "min_order_qty", nullable = false, precision = 10, scale = 3)
    @Builder.Default
    private BigDecimal minOrderQty = BigDecimal.ONE;

    @Column(name = "qty_step", nullable = false, precision = 10, scale = 3)
    @Builder.Default
    private BigDecimal qtyStep = BigDecimal.ONE;

    @Column(name = "max_order_qty", precision = 10, scale = 3)
    private BigDecimal maxOrderQty;

    @Column(name = "shelf_life_days")
    private Integer shelfLifeDays;

    @Column(name = "requires_cold_chain", nullable = false)
    @Builder.Default
    private Boolean requiresColdChain = false;

    @Column(name = "storage_instructions", length = 300)
    private String storageInstructions;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private Integer sortOrder = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "comboVariant", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<ComboItem> comboComponents = new ArrayList<>();

    @PrePersist
    void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

