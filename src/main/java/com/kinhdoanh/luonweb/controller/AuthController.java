package com.kinhdoanh.luonweb.controller;

import com.kinhdoanh.luonweb.dto.*;
import com.kinhdoanh.luonweb.entity.OtpToken;
import com.kinhdoanh.luonweb.service.EmailService;
import com.kinhdoanh.luonweb.service.OtpService;
import com.kinhdoanh.luonweb.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequiredArgsConstructor
public class AuthController {

    private final UserService userService;
    private final OtpService otpService;
    private final EmailService emailService;
    private final UserDetailsService userDetailsService;
    private final PasswordEncoder passwordEncoder;

    @GetMapping("/login")
    public String loginPage(Model model) {
        if (!model.containsAttribute("loginRequest")) {
            model.addAttribute("loginRequest", new LoginRequest());
        }
        return "login";
    }

    @PostMapping("/auth/login")
    public String processLogin(@Valid @ModelAttribute("loginRequest") LoginRequest request,
                               BindingResult result,
                               Model model,
                               HttpServletRequest httpRequest) {
        if (result.hasErrors()) {
            return "login";
        }

        try {
            UserDetails userDetails = userDetailsService.loadUserByUsername(request.getEmail());
            if (!passwordEncoder.matches(request.getPassword(), userDetails.getPassword())) {
                result.rejectValue("password", "error.loginRequest", "Mật khẩu không chính xác");
                return "login";
            }

            // Admin bỏ qua OTP, đăng nhập trực tiếp
            boolean isAdmin = userDetails.getAuthorities().stream()
                    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));

            if (isAdmin) {
                UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                        userDetails, null, userDetails.getAuthorities());
                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(httpRequest));
                SecurityContextHolder.getContext().setAuthentication(authToken);

                HttpSession session = httpRequest.getSession(true);
                session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY, SecurityContextHolder.getContext());

                return "redirect:/admin";
            }

            // User thường: gửi OTP như bình thường
            String otp = otpService.generateOtp(request.getEmail(), OtpToken.TokenType.LOGIN_OTP);
            emailService.sendOtpEmail(request.getEmail(), otp); 

            return "redirect:/verify-otp?email=" + request.getEmail();
        } catch (org.springframework.security.core.userdetails.UsernameNotFoundException e) {
            result.rejectValue("email", "error.loginRequest", "Email không tồn tại");
            return "login";
        } catch (Exception e) {
            e.printStackTrace(); // Log the actual error
            result.rejectValue("email", "error.loginRequest", "Lỗi hệ thống hoặc gửi OTP thất bại: " + e.getMessage());
            return "login";
        }
    }
    //Để bảo mật cao nhất, người ta thường gộp chung một thông báo mập mờ cho cả 2 trường hợp:

    @GetMapping("/verify-otp")
    public String verifyOtpPage(@RequestParam("email") String email, Model model) {
        model.addAttribute("email", email);
        return "verify-otp";
    }

    @PostMapping("/auth/verify-otp")
    public String processVerifyOtp(@RequestParam("email") String email,
                                   @RequestParam("otp") String otp,
                                   Model model,
                                   HttpServletRequest httpRequest) {
        model.addAttribute("email", email);

        if (otp == null || otp.length() != 6) {
            model.addAttribute("error", "Mã OTP phải gồm 6 chữ số");
            return "verify-otp";
        }

        boolean isValid = otpService.validateOtp(email, otp, OtpToken.TokenType.LOGIN_OTP);
        if (!isValid) {
            model.addAttribute("error", "Mã OTP không hợp lệ hoặc đã hết hạn");
            return "verify-otp";
        }

        UserDetails userDetails = userDetailsService.loadUserByUsername(email);
        UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                userDetails, null, userDetails.getAuthorities());
        authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(httpRequest));
        SecurityContextHolder.getContext().setAuthentication(authToken);

        HttpSession session = httpRequest.getSession(true);
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY, SecurityContextHolder.getContext());

        return "redirect:/";
    }

    @PostMapping("/auth/resend-otp")
    public String resendOtp(@RequestParam("email") String email, RedirectAttributes redirectAttributes) {
        if (email == null || !userService.existsByEmail(email)) {
            redirectAttributes.addFlashAttribute("error", "Email không hợp lệ");
            return "redirect:/login";
        }
        
        String otp = otpService.generateOtp(email, OtpToken.TokenType.LOGIN_OTP);
        emailService.sendOtpEmail(email, otp);
        redirectAttributes.addFlashAttribute("successMessage", "Đã gửi lại mã OTP thành công");
        return "redirect:/verify-otp?email=" + email;
    }

    @GetMapping("/register")
    public String registerPage(Model model) {
        if (!model.containsAttribute("registerRequest")) {
            model.addAttribute("registerRequest", new RegisterRequest());
        }
        return "register";
    }

    @PostMapping("/auth/register")
    public String processRegister(@Valid @ModelAttribute("registerRequest") RegisterRequest request,
                                  BindingResult result) {
        if (result.hasErrors()) {
            return "register";
        }

        try {
            userService.registerUser(request);
            return "redirect:/login?registered";
        } catch (IllegalArgumentException e) {
            if (e.getMessage().contains("mật khẩu")) {
                result.rejectValue("confirmPassword", "error.registerRequest", e.getMessage());
            } else {
                result.rejectValue("email", "error.registerRequest", e.getMessage());
            }
            return "register";
        }
    }

    @GetMapping("/forgot-password")
    public String forgotPasswordPage(Model model) {
        if (!model.containsAttribute("forgotPasswordRequest")) {
            model.addAttribute("forgotPasswordRequest", new ForgotPasswordRequest());
        }
        return "forgot-password";
    }

    @PostMapping("/auth/forgot-password")
    public String processForgotPassword(@Valid @ModelAttribute("forgotPasswordRequest") ForgotPasswordRequest request,
                                        BindingResult result,
                                        HttpServletRequest httpRequest,
                                        RedirectAttributes redirectAttributes) {
        if (result.hasErrors()) {
            return "forgot-password";
        }

        if (!userService.existsByEmail(request.getEmail())) {
            result.rejectValue("email", "error.forgotPasswordRequest", "Email không tồn tại trong hệ thống");
            return "forgot-password";
        }

        String token = otpService.generateResetToken(request.getEmail());
        String appUrl = httpRequest.getScheme() + "://" + httpRequest.getServerName() + ":" + httpRequest.getServerPort();
        String resetLink = appUrl + "/reset-password?token=" + token;
        
        emailService.sendResetPasswordEmail(request.getEmail(), resetLink);
        
        redirectAttributes.addFlashAttribute("successMessage", "Email khôi phục mật khẩu đã được gửi!");
        return "redirect:/forgot-password";
    }

    @GetMapping("/reset-password")
    public String resetPasswordPage(@RequestParam("token") String token, Model model) {
        if (!otpService.validateResetToken(token)) {
            model.addAttribute("errorMessage", "Đường dẫn khôi phục mật khẩu không hợp lệ hoặc đã hết hạn.");
            return "reset-password";
        }
        
        ResetPasswordRequest request = new ResetPasswordRequest();
        request.setToken(token);
        model.addAttribute("resetPasswordRequest", request);
        return "reset-password";
    }

    @PostMapping("/auth/reset-password")
    public String processResetPassword(@Valid @ModelAttribute("resetPasswordRequest") ResetPasswordRequest request,
                                       BindingResult result,
                                       Model model) {
        if (result.hasErrors()) {
            return "reset-password";
        }

        if (!request.getNewPassword().equals(request.getConfirmPassword())) {
            result.rejectValue("confirmPassword", "error.resetPasswordRequest", "Mật khẩu xác nhận không khớp");
            return "reset-password";
        }

        if (!otpService.validateResetToken(request.getToken())) {
            model.addAttribute("errorMessage", "Đường dẫn khôi phục mật khẩu không hợp lệ hoặc đã hết hạn.");
            return "reset-password";
        }

        String email = otpService.getEmailByResetToken(request.getToken());
        if (email != null) {
            userService.updatePassword(email, request.getNewPassword());
            otpService.markResetTokenAsUsed(request.getToken());
        }

        return "redirect:/login?passwordReset";
    }
}
