package com.kinhdoanh.luonweb.entity.catalog;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.*;

import java.io.Serializable;

@Embeddable
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode
public class ComboItemId implements Serializable {

    @Column(name = "combo_variant_id")
    private Long comboVariantId;

    @Column(name = "component_variant_id")
    private Long componentVariantId;
}

