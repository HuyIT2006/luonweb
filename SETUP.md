# Lươn Việt - Hướng dẫn Setup & Tổng kết

> Website bán sản phẩm lươn - Spring Boot + Thymeleaf + MySQL

## Tổng kết công việc đã hoàn thành

### Giao diện (7 trang)
- **Trang chủ** - Hero section, danh mục lươn, sản phẩm bán chạy, promo banner
- **Đăng nhập** - Split-panel, Google login, validation, thông báo lỗi
- **Đăng ký** - Validation chi tiết (tên, email, mật khẩu, xác nhận)
- **Xác thực OTP** - 6 ô input tự nhảy, countdown 60s, hỗ trợ paste
- **Quên mật khẩu** - Gửi link reset qua email
- **Đặt lại mật khẩu** - Form mật khẩu mới + xác nhận
- **Header** - Hiện/ẩn nút đăng nhập/đăng xuất tùy trạng thái

### Backend MVC (17 file Java)
- 2 Entity (User, OtpToken)
- 2 Repository
- 5 DTO với Jakarta Validation
- 5 Service (User, OTP, Email, UserDetails, OAuth2)
- 2 Controller (Home, Auth)
- 1 SecurityConfig

### Luồng hoạt động
```
Đăng ký → Validate → BCrypt → Lưu DB → Redirect login
Đăng nhập → Validate → Gửi OTP email → Nhập OTP → Xác thực
Google Login → OAuth2 → Tạo/cập nhật user → Xác thực
Quên MK → Gửi link UUID → Đặt lại mật khẩu mới
```

---

## BẠN CẦN LÀM GÌ ĐỂ CHẠY

### 1. Cấu hình Email (BẮT BUỘC cho OTP)

Mở `src/main/resources/application.properties`, thay:

```properties
spring.mail.username=EMAIL_CUA_BAN@gmail.com
spring.mail.password=APP_PASSWORD_16_KY_TU
```

**Cách lấy App Password:**
1. Bật Xác minh 2 bước trên Google Account
2. Vào: https://myaccount.google.com/apppasswords
3. Tạo App Password → copy 16 ký tự

### 2. Cấu hình Google OAuth2 (TÙY CHỌN)

Mở `src/main/resources/application.properties`, thay:

```properties
spring.security.oauth2.client.registration.google.client-id=YOUR_CLIENT_ID
spring.security.oauth2.client.registration.google.client-secret=YOUR_CLIENT_SECRET
```

**Cách lấy:**
1. Vào Google Cloud Console: https://console.cloud.google.com
2. Tạo Project → APIs & Services → Credentials → OAuth Client ID
3. Authorized redirect URI: `http://localhost:8080/login/oauth2/code/google`

> Nếu chưa config, dự án vẫn chạy nhưng nút Google sẽ lỗi

### 3. Chạy dự án

```bash
# Đảm bảo XAMPP MySQL đang chạy, database luonweb_db tồn tại
./mvnw.cmd spring-boot:run
```

Truy cập: http://localhost:8080

### 4. Test

1. Đăng ký: http://localhost:8080/register
2. Đăng nhập: http://localhost:8080/login → nhận OTP qua email
3. Quên MK: http://localhost:8080/forgot-password

---

## Cấu trúc thư mục

```
src/main/
├── java/com/kinhdoanh/luonweb/
│   ├── config/SecurityConfig.java
│   ├── controller/
│   │   ├── HomeController.java
│   │   └── AuthController.java
│   ├── dto/
│   │   ├── LoginRequest.java
│   │   ├── RegisterRequest.java
│   │   ├── OtpVerifyRequest.java
│   │   ├── ForgotPasswordRequest.java
│   │   └── ResetPasswordRequest.java
│   ├── entity/
│   │   ├── User.java
│   │   └── OtpToken.java
│   ├── repository/
│   │   ├── UserRepository.java
│   │   └── OtpTokenRepository.java
│   ├── service/
│   │   ├── UserService.java
│   │   ├── OtpService.java
│   │   ├── EmailService.java
│   │   ├── CustomUserDetailsService.java
│   │   └── CustomOAuth2UserService.java
│   └── LuonwebApplication.java
└── resources/
    ├── application.properties
    ├── static/css/main.css
    └── templates/
        ├── fragments/Header.html
        ├── index.html
        ├── login.html
        ├── register.html
        ├── verify-otp.html
        ├── forgot-password.html
        └── reset-password.html
```

## Lưu ý bảo mật

- **KHÔNG commit** `application.properties` lên GitHub (chứa password/secret)
- Thêm vào `.gitignore`: `src/main/resources/application.properties`
- Production nên dùng biến môi trường thay cho hardcode
rontend (7 file)
File	Mô tả
admin.css
CSS riêng cho giao diện admin
sidebar.html
Sidebar điều hướng
dashboard.html
Tổng quan: doanh thu, đơn hàng, user
products.html
Danh sách sản phẩm
product-form.html
Form thêm/sửa sản phẩm
orders.html
Quản lý đơn hàng (đổi trạng thái inline)
users.html
Quản lý người dùng (đổi quyền, vô hiệu)
Để test:
Bật MySQL trên XAMPP
Chạy .\mvnw.cmd spring-boot:run
Truy cập http://localhost:8080/admin
Đăng nhập bằng tài khoản admin:
Email: admin@luonviet.vn
Mật khẩu: admin123
