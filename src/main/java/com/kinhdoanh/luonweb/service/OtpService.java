package com.kinhdoanh.luonweb.service;

import com.kinhdoanh.luonweb.entity.OtpToken;
import com.kinhdoanh.luonweb.repository.OtpTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class OtpService {
    private final OtpTokenRepository otpTokenRepository;

    @Value("${app.otp.expiry-minutes:5}")
    private int otpExpiryMinutes;

    @Value("${app.otp.max-attempts:5}")
    private int maxAttempts;

    @Value("${app.reset-token.expiry-minutes:30}")
    private int resetTokenExpiryMinutes;

    @Transactional
    public String generateOtp(String email, OtpToken.TokenType type) {
        // Invalidate old OTPs of this type for this email
        Optional<OtpToken> oldToken = otpTokenRepository.findTopByEmailAndTypeAndUsedFalseOrderByIdDesc(email, type);
        oldToken.ifPresent(token -> {
            token.setUsed(true);
            otpTokenRepository.save(token);
        });

        // Generate 6 digit OTP
        SecureRandom random = new SecureRandom();
        int otpValue = 100000 + random.nextInt(900000);
        String otp = String.valueOf(otpValue);

        OtpToken otpToken = OtpToken.builder()
                .email(email)
                .token(otp)
                .type(type)
                .expiryTime(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .build();

        otpTokenRepository.save(otpToken);
        return otp;
    }

    @Transactional
    public boolean validateOtp(String email, String otp, OtpToken.TokenType type) {
        Optional<OtpToken> tokenOpt = otpTokenRepository.findTopByEmailAndTypeAndUsedFalseOrderByIdDesc(email, type);
        
        if (tokenOpt.isEmpty()) {
            return false;
        }

        OtpToken token = tokenOpt.get();

        if (token.isExpired()) {
            return false;
        }

        if (token.getAttempts() >= maxAttempts) {
            token.setUsed(true);
            otpTokenRepository.save(token);
            return false;
        }

        if (!token.getToken().equals(otp)) {
            token.setAttempts(token.getAttempts() + 1);
            otpTokenRepository.save(token);
            return false;
        }

        token.setUsed(true);
        otpTokenRepository.save(token);
        return true;
    }

    @Transactional
    public String generateResetToken(String email) {
        String token = UUID.randomUUID().toString();
        
        OtpToken resetToken = OtpToken.builder()
                .email(email)
                .token(token)
                .type(OtpToken.TokenType.RESET_PASSWORD)
                .expiryTime(LocalDateTime.now().plusMinutes(resetTokenExpiryMinutes))
                .build();

        otpTokenRepository.save(resetToken);
        return token;
    }

    public boolean validateResetToken(String token) {
        Optional<OtpToken> tokenOpt = otpTokenRepository.findByTokenAndTypeAndUsedFalse(token, OtpToken.TokenType.RESET_PASSWORD);
        if (tokenOpt.isEmpty() || tokenOpt.get().isExpired()) {
            return false;
        }
        return true;
    }
    
    @Transactional
    public void markResetTokenAsUsed(String token) {
        otpTokenRepository.findByTokenAndTypeAndUsedFalse(token, OtpToken.TokenType.RESET_PASSWORD).ifPresent(otpToken -> {
            otpToken.setUsed(true);
            otpTokenRepository.save(otpToken);
        });
    }

    public String getEmailByResetToken(String token) {
        return otpTokenRepository.findByTokenAndTypeAndUsedFalse(token, OtpToken.TokenType.RESET_PASSWORD)
                .map(OtpToken::getEmail)
                .orElse(null);
    }
}
