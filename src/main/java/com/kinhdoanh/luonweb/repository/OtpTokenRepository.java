package com.kinhdoanh.luonweb.repository;

import com.kinhdoanh.luonweb.entity.OtpToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface OtpTokenRepository extends JpaRepository<OtpToken, Long> {
    Optional<OtpToken> findTopByEmailAndTypeAndUsedFalseOrderByIdDesc(String email, OtpToken.TokenType type);
    Optional<OtpToken> findByTokenAndTypeAndUsedFalse(String token, OtpToken.TokenType type);
    void deleteByExpiryTimeBefore(LocalDateTime time);
}
