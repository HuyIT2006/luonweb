package com.kinhdoanh.luonweb.service;

import com.kinhdoanh.luonweb.dto.RegisterRequest;
import com.kinhdoanh.luonweb.entity.User;
import com.kinhdoanh.luonweb.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public User registerUser(RegisterRequest request) {
        if (!request.getPassword().equals(request.getConfirmPassword())) {
            throw new IllegalArgumentException("Mật khẩu xác nhận không khớp");
        }

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Email đã được sử dụng");
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword())) //gọi hàm .encode() của PasswordEncoder để mã hóa mật khẩu
                .role(User.Role.USER)
                .provider(User.AuthProvider.LOCAL)
                .enabled(true)
                .build();

        return userRepository.save(user);
    }

    public Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    public boolean existsByEmail(String email) {
        return userRepository.existsByEmail(email);
    }

    @Transactional
    public void updatePassword(String email, String newPassword) {
        userRepository.findByEmail(email).ifPresent(user -> {
            user.setPassword(passwordEncoder.encode(newPassword));
            userRepository.save(user);
        });
    }

    @Transactional
    public User processOAuth2User(OAuth2User oAuth2User) {
        String email = oAuth2User.getAttribute("email");
        String name = oAuth2User.getAttribute("name");
        String sub = oAuth2User.getAttribute("sub");

        Optional<User> userOptional = userRepository.findByEmail(email);
        User user;

        if (userOptional.isPresent()) {
            user = userOptional.get();
            if (!User.AuthProvider.GOOGLE.equals(user.getProvider())) {
                user.setProvider(User.AuthProvider.GOOGLE);
                user.setProviderId(sub);
                user = userRepository.save(user);
            }
        } else {
            user = User.builder()
                    .email(email)
                    .fullName(name != null ? name : "Người dùng Google")
                    .provider(User.AuthProvider.GOOGLE)
                    .providerId(sub)
                    .role(User.Role.USER)
                    .enabled(true)
                    .build();
            user = userRepository.save(user);
        }

        return user;
    }
}
