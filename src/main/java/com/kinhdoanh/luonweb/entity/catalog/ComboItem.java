package com.kinhdoanh.luonweb.entity.catalog;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(
    name = "combo_items",
    indexes = @Index(name = "idx_combo_component", columnList = "component_variant_id")
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@ToString(exclude = {"comboVariant", "componentVariant"})
public class ComboItem {

    @EmbeddedId
    @EqualsAndHashCode.Include
    private ComboItemId id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @MapsId("comboVariantId")
    @JoinColumn(name = "combo_variant_id", nullable = false, foreignKey = @ForeignKey(name = "fk_combo_parent"))
    private ProductVariant comboVariant;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @MapsId("componentVariantId")
    @JoinColumn(name = "component_variant_id", nullable = false, foreignKey = @ForeignKey(name = "fk_combo_component"))
    private ProductVariant componentVariant;

    @Column(nullable = false, precision = 10, scale = 3)
    private BigDecimal quantity;
}

