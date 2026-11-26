package com.kinhdoanh.luonweb.entity.auth;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(
    name = "staff_profiles",
    uniqueConstraints = @UniqueConstraint(name = "uk_staff_code", columnNames = "employee_code")
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
@ToString(exclude = "user")
public class StaffProfile {

    @Id
    @Column(name = "user_id")
    @EqualsAndHashCode.Include
    private Long userId;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @MapsId
    @JoinColumn(name = "user_id", nullable = false, foreignKey = @ForeignKey(name = "fk_sp_user"))
    private User user;

    @Column(name = "employee_code", nullable = false, length = 20)
    private String employeeCode;

    @Column(length = 100)
    private String position;

    @Column(name = "hired_at")
    private LocalDate hiredAt;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;
}

