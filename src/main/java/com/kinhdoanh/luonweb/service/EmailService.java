package com.kinhdoanh.luonweb.service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {
    private final JavaMailSender mailSender;

    public void sendOtpEmail(String to, String otp) {
        String subject = "Mã xác thực đăng nhập - Lươn Việt";
        String content = "<div style=\"font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;\">"
                + "<h2 style=\"color: #2e6c80;\">Xác thực đăng nhập</h2>"
                + "<p>Xin chào,</p>"
                + "<p>Bạn đã yêu cầu mã xác thực để đăng nhập vào website Lươn Việt. Đây là mã OTP của bạn:</p>"
                + "<h1 style=\"font-size: 32px; letter-spacing: 5px; color: #d9534f; background: #f9f9f9; padding: 10px; text-align: center; border-radius: 5px;\">"
                + otp + "</h1>"
                + "<p>Mã này có hiệu lực trong 5 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai.</p>"
                + "<hr style=\"border-top: 1px solid #eee;\"/>"
                + "<p style=\"font-size: 12px; color: #888;\">Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email này.</p>"
                + "</div>";

        sendHtmlEmail(to, subject, content);
    }

    public void sendResetPasswordEmail(String to, String resetLink) {
        String subject = "Khôi phục mật khẩu - Lươn Việt";
        String content = "<div style=\"font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;\">"
                + "<h2 style=\"color: #2e6c80;\">Yêu cầu khôi phục mật khẩu</h2>"
                + "<p>Xin chào,</p>"
                + "<p>Bạn đã yêu cầu đặt lại mật khẩu cho tài khoản tại Lươn Việt. Vui lòng click vào nút bên dưới để tiến hành đặt lại mật khẩu:</p>"
                + "<div style=\"text-align: center; margin: 30px 0;\">"
                + "<a href=\"" + resetLink + "\" style=\"background-color: #4CAF50; color: white; padding: 14px 25px; text-align: center; text-decoration: none; display: inline-block; border-radius: 4px; font-weight: bold;\">Đặt lại mật khẩu</a>"
                + "</div>"
                + "<p>Hoặc bạn có thể sao chép và dán đường dẫn sau vào trình duyệt:</p>"
                + "<p><a href=\"" + resetLink + "\">" + resetLink + "</a></p>"
                + "<p>Đường dẫn này có hiệu lực trong 30 phút.</p>"
                + "<hr style=\"border-top: 1px solid #eee;\"/>"
                + "<p style=\"font-size: 12px; color: #888;\">Nếu bạn không yêu cầu khôi phục mật khẩu, vui lòng bỏ qua email này và đảm bảo tài khoản của bạn được an toàn.</p>"
                + "</div>";

        sendHtmlEmail(to, subject, content);
    }

    private void sendHtmlEmail(String to, String subject, String content) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(content, true);
            mailSender.send(message);
            log.info("Email sent to {}", to);
        } catch (MessagingException e) {
            log.error("Lỗi tạo email: {}", e.getMessage());
        } catch (org.springframework.mail.MailException e) {
            log.error("Lỗi gửi email (Authentication failed hoặc mạng). Nội dung email:\nTo: {}\nSubject: {}\nContent: {}", to, subject, content);
            System.out.println("======================================================");
            System.out.println("MÃ OTP HOẶC LINK CỦA BẠN LÀ (DÙNG ĐỂ TEST LOCAL):");
            System.out.println("GỬI TỚI: " + to);
            System.out.println("NỘI DUNG: " + content);
            System.out.println("======================================================");
        }
    }
}
