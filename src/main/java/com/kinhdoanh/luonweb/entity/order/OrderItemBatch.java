package com.kinhdoanh.luonweb.entity.order;


import com.kinhdoanh.luonweb.entity.inventory.InventoryBatch;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(
    name = "order_item_batches",
    uniqueConstraints = @UniqueConstraint(name = "uk_oib", columnNames = {"order_item_id", "batch_id"}),
    indexes = @Index(name = "idx_oib_batch", columnList = "batch_id")
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@ToString(exclude = {"orderItem", "batch"})
public class OrderItemBatch {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @EqualsAndHashCode.Include
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_item_id", nullable = false, foreignKey = @ForeignKey(name = "fk_oib_item"))
    private OrderItem orderItem;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "batch_id", nullable = false, foreignKey = @ForeignKey(name = "fk_oib_batch"))
    private InventoryBatch batch;

    @Column(nullable = false, precision = 12, scale = 3)
    private BigDecimal quantity;
}

