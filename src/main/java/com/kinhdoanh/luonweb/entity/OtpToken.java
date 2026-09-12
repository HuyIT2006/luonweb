package com.kinhdoanh.luonweb.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "otp_tokens")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OtpToken {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String token; // 6-digit OTP or UUID reset token

    @Column(nullable = false)
    private String email;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TokenType type; // LOGIN_OTP or RESET_PASSWORD

    @Column(nullable = false)
    private LocalDateTime expiryTime;

    @Builder.Default
    private int attempts = 0;

    @Builder.Default
    private boolean used = false;

    public boolean isExpired() { return LocalDateTime.now().isAfter(expiryTime); }

    public enum TokenType { LOGIN_OTP, RESET_PASSWORD }
}
