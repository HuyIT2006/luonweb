package com.kinhdoanh.luonweb.entity.catalog;


import com.kinhdoanh.luonweb.entity.auth.User;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "price_histories",
    indexes = @Index(name = "idx_price_hist", columnList = "variant_id, created_at")
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@ToString(exclude = {"variant", "changedBy"})
public class PriceHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @EqualsAndHashCode.Include
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "variant_id", nullable = false, foreignKey = @ForeignKey(name = "fk_ph_variant"))
    private ProductVariant variant;

    @Column(name = "old_price", nullable = false, precision = 12, scale = 0)
    private BigDecimal oldPrice;

    @Column(name = "new_price", nullable = false, precision = 12, scale = 0)
    private BigDecimal newPrice;

    @Column(name = "old_sale_price", precision = 12, scale = 0)
    private BigDecimal oldSalePrice;

    @Column(name = "new_sale_price", precision = 12, scale = 0)
    private BigDecimal newSalePrice;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "changed_by", nullable = false, foreignKey = @ForeignKey(name = "fk_ph_user"))
    private User changedBy;

    @Column(length = 255)
    private String reason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}

