package com.kinhdoanh.luonweb.entity.inventory;


import com.kinhdoanh.luonweb.entity.catalog.ProductVariant;
import com.kinhdoanh.luonweb.entity.auth.User;
import com.kinhdoanh.luonweb.entity.enums.BatchStatus;
import com.kinhdoanh.luonweb.entity.enums.StorageCondition;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "inventory_batches",
    uniqueConstraints = @UniqueConstraint(name = "uk_batch_code", columnNames = "batch_code"),
    indexes = {
        @Index(name = "idx_batch_fefo", columnList = "variant_id, status, expiry_date"),
        @Index(name = "idx_batch_expiry", columnList = "expiry_date, status"),
        @Index(name = "idx_batch_supplier", columnList = "supplier_id")
    }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@ToString(exclude = {"variant", "supplier", "receivedBy"})
public class InventoryBatch {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @EqualsAndHashCode.Include
    private Long id;

    @Column(name = "batch_code", nullable = false, length = 50)
    private String batchCode;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "variant_id", nullable = false, foreignKey = @ForeignKey(name = "fk_batch_variant"))
    private ProductVariant variant;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "supplier_id", foreignKey = @ForeignKey(name = "fk_batch_supplier"))
    private Supplier supplier;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "received_by", foreignKey = @ForeignKey(name = "fk_batch_received_by"))
    private User receivedBy;

    @Enumerated(EnumType.STRING)
    @Column(name = "storage_condition", nullable = false, length = 20)
    private StorageCondition storageCondition;

    @Column(name = "produced_date")
    private LocalDate producedDate;

    @Column(name = "received_date", nullable = false)
    private LocalDate receivedDate;

    @Column(name = "expiry_date", nullable = false)
    private LocalDate expiryDate;

    @Column(name = "quantity_received", nullable = false, precision = 12, scale = 3)
    private BigDecimal quantityReceived;

    @Column(name = "quantity_remaining", nullable = false, precision = 12, scale = 3)
    private BigDecimal quantityRemaining;

    @Column(name = "unit_cost", nullable = false, precision = 12, scale = 0)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private BatchStatus status = BatchStatus.AVAILABLE;

    @Column(length = 300)
    private String note;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

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

