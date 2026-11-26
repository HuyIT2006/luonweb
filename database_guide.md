# Tài liệu giải thích cơ sở dữ liệu `eel_shop`

> Database cho website thương mại điện tử bán **lươn**: lươn tươi sống, lươn sơ chế, lươn chế biến sẵn (đóng hộp, hút chân không), combo lươn kèm gia vị.
> Tài liệu này đi kèm hai file `schema.dbml` (sơ đồ ERD) và `schema.sql` (script MySQL 8.0.16+).

---

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Quy ước thiết kế](#2-quy-ước-thiết-kế)
3. [Sơ đồ quan hệ tổng quát](#3-sơ-đồ-quan-hệ-tổng-quát)
4. [Nhóm 1: Tài khoản và phân quyền](#4-nhóm-1-tài-khoản-và-phân-quyền-auth--rbac)
5. [Nhóm 2: Danh mục và sản phẩm](#5-nhóm-2-danh-mục-và-sản-phẩm-catalog)
6. [Nhóm 3: Kho theo lô](#6-nhóm-3-kho-theo-lô-inventory)
7. [Nhóm 4: Giỏ hàng](#7-nhóm-4-giỏ-hàng-cart)
8. [Nhóm 5: Đơn hàng](#8-nhóm-5-đơn-hàng-ordering)
9. [Nhóm 6: Đánh giá và bài viết](#9-nhóm-6-đánh-giá-và-bài-viết)
10. [View và Stored Procedure](#10-view-và-stored-procedure)
11. [Các luồng nghiệp vụ end-to-end](#11-các-luồng-nghiệp-vụ-end-to-end)
12. [Chiến lược index](#12-chiến-lược-index)
13. [Việc ứng dụng phải tự đảm bảo](#13-việc-ứng-dụng-phải-tự-đảm-bảo)
14. [Dữ liệu mẫu (seed)](#14-dữ-liệu-mẫu-seed)

---

## 1. Tổng quan

### 1.1. Bốn tác nhân và cách database phản ánh

| Tác nhân | Có dòng trong `users`? | Được nhận diện bằng | Dữ liệu liên quan |
|---|---|---|---|
| **Guest** (vãng lai) | Không | `carts.guest_token` (cookie HttpOnly) | `carts`, `cart_items` |
| **Customer** (khách hàng) | Có, role `customer` | `users.id` | `customer_profiles`, `user_addresses`, `orders`, `reviews`, `loyalty_transactions`, `carts` |
| **Staff** (nhân viên) | Có, role `staff` | `users.id` | `staff_profiles`, `orders.assigned_staff_id`, `order_status_histories.changed_by`, `inventory_transactions.performed_by` |
| **Admin** | Có, role `admin` | `users.id` | Có toàn bộ quyền; dấu vết ở `price_histories.changed_by`, `user_roles.assigned_by`... |

### 1.2. Thống kê

- **27 bảng**, chia thành 6 nhóm (`TableGroup` trong DBML).
- **3 view**: `v_variant_available_stock`, `v_batches_expiring_soon`, `v_daily_revenue`.
- **1 stored procedure**: `sp_merge_guest_cart`.
- Engine **InnoDB**, bộ ký tự **utf8mb4** (hỗ trợ đầy đủ tiếng Việt và emoji).

### 1.3. Bốn bài toán nghiệp vụ cốt lõi và cách giải quyết

| Bài toán | Giải pháp trong database |
|---|---|
| Khách vãng lai vẫn thêm được vào giỏ | Giỏ hàng gắn với `guest_token` thay vì `user_id`; bảng `carts` dùng chung cho cả hai loại khách |
| Phân quyền linh hoạt | RBAC 5 bảng: `users` ↔ `user_roles` ↔ `roles` ↔ `role_permissions` ↔ `permissions` |
| Lươn tươi có hạn dùng rất ngắn | Kho quản lý **theo lô** (`inventory_batches`), mỗi lô có ngày nhập, ngày hết hạn; xuất kho theo **FEFO** |
| Biết ai làm gì với đơn hàng | `orders.assigned_staff_id` (người phụ trách) + `order_status_histories` (lịch sử từng lần đổi trạng thái kèm người đổi) |

---

## 2. Quy ước thiết kế

### 2.1. Kiểu dữ liệu

| Loại dữ liệu | Kiểu dùng | Lý do |
|---|---|---|
| Khóa chính bảng lớn (users, orders, products...) | `BIGINT UNSIGNED AUTO_INCREMENT` | Không lo hết số khi hệ thống lớn |
| Khóa chính bảng danh mục nhỏ (roles, categories, suppliers, coupons) | `INT UNSIGNED AUTO_INCREMENT` | Tiết kiệm bộ nhớ, ít bản ghi |
| Tiền (VND) | `DECIMAL(12,0)` | Tiền VND không có phần lẻ; DECIMAL tránh sai số của FLOAT |
| Số lượng hàng | `DECIMAL(10,3)` hoặc `DECIMAL(12,3)` | Lươn sống bán theo kg (0.5, 1.5...), hàng đóng gói bán theo cái (1, 2, 3...). Dùng chung một kiểu cho cả hai |
| Trạng thái, phân loại cố định | `ENUM` | Gọn, có kiểm tra giá trị ngay ở database |
| Cờ đúng/sai | `TINYINT(1)` | MySQL không có kiểu boolean thật |
| Thời gian | `DATETIME` | Nên thống nhất ứng dụng ghi theo một múi giờ (khuyến nghị UTC hoặc UTC+7 nhất quán) |

### 2.2. Quy ước đặt tên

- Tên bảng: số nhiều, `snake_case` (`order_items`, `inventory_batches`).
- Khóa ngoại: `<bảng_số_ít>_id` (`user_id`, `variant_id`), trừ khi có ý nghĩa vai trò riêng (`assigned_staff_id`, `changed_by`, `performed_by`).
- Khóa duy nhất: `uk_<bảng>_<cột>`. Index thường: `idx_<bảng>_<mục đích>`. Khóa ngoại: `fk_<viết tắt>_<đối tượng>`. Ràng buộc kiểm tra: `chk_<...>`.
- Cột thời gian chuẩn: `created_at`, `updated_at` (tự cập nhật bằng `ON UPDATE CURRENT_TIMESTAMP`), `deleted_at` (xóa mềm).

### 2.3. Ba kỹ thuật thiết kế được dùng xuyên suốt

**a) Snapshot (chụp lại dữ liệu tại thời điểm đặt hàng).**
`order_items` lưu lại `product_name`, `variant_name`, `sku`, `unit`, `unit_price` ngay lúc mua. Sau này admin đổi giá hoặc đổi tên sản phẩm thì đơn cũ vẫn giữ nguyên. Tương tự `orders` lưu bản sao địa chỉ giao hàng thay vì chỉ trỏ tới `user_addresses`.

**b) Sổ cái (ledger) chỉ ghi thêm.**
`inventory_transactions` và `loyalty_transactions` không bị sửa hay xóa, mỗi biến động là một dòng mới. Số dư hiện tại (`quantity_remaining`, `loyalty_points`) là kết quả cộng dồn của sổ cái, được lưu sẵn để đọc nhanh. Khi nghi ngờ lệch số, đối chiếu lại bằng sổ cái.

**c) Lịch sử thay đổi (audit trail).**
`order_status_histories`, `price_histories`, `inventory_transactions` đều ghi lại *ai* làm *khi nào* và *thay đổi gì*.

---

## 3. Sơ đồ quan hệ tổng quát

Ký hiệu: `1──N` là một-nhiều, `1──1` là một-một, `N──N` là nhiều-nhiều (qua bảng trung gian).

```
                          ┌────────────── NHÓM 1: AUTH & RBAC ──────────────┐
  roles ──N──N── permissions          (qua role_permissions)
    │
    └──N──N── users                   (qua user_roles)
                │
                ├──1──1── customer_profiles
                ├──1──1── staff_profiles
                ├──1──N── user_addresses
                ├──1──N── loyalty_transactions
                │
                ├──1──1── carts ──1──N── cart_items ──N──1──┐
                │         (giỏ của khách đã đăng nhập)      │
                │                                           │
                ├──1──N── orders ──1──N── order_items ──N──1┤
                │            │                 │            │
                │            │                 └─1─N─ order_item_batches ─N─1─┐
                │            ├──1──N── order_status_histories                 │
                │            └──N──1── coupons                                │
                │                                                             │
                ├──1──N── reviews ──1──1── order_items                        │
                └──1──N── articles                                            │
                                                                              │
  categories ──1──N── products ──1──N── product_variants ◄────────────────────┤
  (tự tham chiếu       │                     │   ▲                            │
   cha - con)          └──1──N── product_images  └── combo_items (tự tham chiếu)
                                             │
                                             ├──1──N── price_histories
                                             └──1──N── inventory_batches ◄────┘
                                                            │       ▲
                          suppliers ──1──N──────────────────┘       │
                                                                    │
                                    inventory_batches ──1──N── inventory_transactions

  Giỏ của guest: carts (user_id = NULL, guest_token = '...') không có dòng nào trong users.
```

### 3.1. Danh sách quan hệ chi tiết

| # | Bảng cha (1) | Bảng con (N) | Cột khóa ngoại | Loại | Khi xóa cha |
|---|---|---|---|---|---|
| 1 | `roles` | `role_permissions` | `role_id` | 1–N | CASCADE |
| 2 | `permissions` | `role_permissions` | `permission_id` | 1–N | CASCADE |
| 3 | `users` | `user_roles` | `user_id` | 1–N | CASCADE |
| 4 | `roles` | `user_roles` | `role_id` | 1–N | RESTRICT |
| 5 | `users` | `user_roles` | `assigned_by` | 1–N | RESTRICT |
| 6 | `users` | `customer_profiles` | `user_id` | **1–1** | CASCADE |
| 7 | `users` | `staff_profiles` | `user_id` | **1–1** | CASCADE |
| 8 | `users` | `user_addresses` | `user_id` | 1–N | CASCADE |
| 9 | `users` | `loyalty_transactions` | `user_id` | 1–N | RESTRICT |
| 10 | `orders` | `loyalty_transactions` | `order_id` | 1–N | RESTRICT |
| 11 | `categories` | `categories` | `parent_id` | 1–N (tự tham chiếu) | RESTRICT |
| 12 | `categories` | `products` | `category_id` | 1–N | RESTRICT |
| 13 | `products` | `product_images` | `product_id` | 1–N | CASCADE |
| 14 | `products` | `product_variants` | `product_id` | 1–N | RESTRICT |
| 15 | `product_variants` | `combo_items` | `combo_variant_id` | 1–N | RESTRICT |
| 16 | `product_variants` | `combo_items` | `component_variant_id` | 1–N | RESTRICT |
| 17 | `product_variants` | `price_histories` | `variant_id` | 1–N | RESTRICT |
| 18 | `product_variants` | `inventory_batches` | `variant_id` | 1–N | RESTRICT |
| 19 | `suppliers` | `inventory_batches` | `supplier_id` | 1–N | RESTRICT |
| 20 | `inventory_batches` | `inventory_transactions` | `batch_id` | 1–N | RESTRICT |
| 21 | `orders` | `inventory_transactions` | `order_id` | 1–N | RESTRICT |
| 22 | `users` | `carts` | `user_id` | **1–1** (UNIQUE) | RESTRICT |
| 23 | `carts` | `carts` | `merged_into_cart_id` | 1–N (tự tham chiếu) | RESTRICT |
| 24 | `carts` | `cart_items` | `cart_id` | 1–N | CASCADE |
| 25 | `product_variants` | `cart_items` | `variant_id` | 1–N | RESTRICT |
| 26 | `users` | `orders` | `user_id` | 1–N | RESTRICT |
| 27 | `users` | `orders` | `assigned_staff_id` | 1–N | RESTRICT |
| 28 | `coupons` | `orders` | `coupon_id` | 1–N | RESTRICT |
| 29 | `orders` | `order_items` | `order_id` | 1–N | CASCADE |
| 30 | `product_variants` | `order_items` | `variant_id` | 1–N | RESTRICT |
| 31 | `order_items` | `order_item_batches` | `order_item_id` | 1–N | CASCADE |
| 32 | `inventory_batches` | `order_item_batches` | `batch_id` | 1–N | RESTRICT |
| 33 | `orders` | `order_status_histories` | `order_id` | 1–N | CASCADE |
| 34 | `order_items` | `reviews` | `order_item_id` | **1–1** (UNIQUE) | RESTRICT |
| 35 | `users` | `reviews` | `user_id` | 1–N | RESTRICT |
| 36 | `products` | `reviews` | `product_id` | 1–N | RESTRICT |
| 37 | `users` | `articles` | `author_id` | 1–N | RESTRICT |

Ngoài ra, `users` còn được tham chiếu bởi các cột "người thực hiện" để truy vết: `products.created_by`, `price_histories.changed_by`, `inventory_batches.received_by`, `inventory_transactions.performed_by`, `coupons.created_by`, `orders.cancelled_by`, `order_status_histories.changed_by`, `loyalty_transactions.created_by`, `reviews.moderated_by`.

> **Về `ON DELETE`:** mặc định là RESTRICT (không cho xóa cha khi còn con) để bảo vệ dữ liệu giao dịch. CASCADE chỉ dùng cho dữ liệu *phụ thuộc hoàn toàn* vào cha (ảnh sản phẩm, dòng giỏ hàng, dòng chi tiết đơn...). Với `users`, hệ thống dùng **xóa mềm** (`deleted_at`) nên thực tế gần như không bao giờ xóa cứng.

---
## 4. Nhóm 1: Tài khoản và phân quyền (Auth & RBAC)

Nhóm này gồm 9 bảng: `roles`, `permissions`, `role_permissions`, `users`, `user_roles`, `customer_profiles`, `staff_profiles`, `user_addresses`, `loyalty_transactions`.

### 4.1. Mô hình RBAC (Role-Based Access Control)

```
users ──< user_roles >── roles ──< role_permissions >── permissions
```

- **Permission** (quyền) là hành động nhỏ nhất, đặt tên dạng `module.action`, ví dụ `order.update_status`.
- **Role** (vai trò) là một nhóm quyền, ví dụ `staff`.
- **User** được gán một hoặc nhiều role. Quyền thực tế của user là **hợp (union)** quyền của tất cả role.
- Ứng dụng chỉ kiểm tra **mã quyền**, không kiểm tra tên role. Sau này muốn thêm role "Quản lý kho" chỉ cần thêm dữ liệu, không sửa code.

Lấy toàn bộ quyền của một user:

```sql
SELECT DISTINCT p.code
FROM user_roles ur
JOIN role_permissions rp ON rp.role_id = ur.role_id
JOIN permissions p       ON p.id = rp.permission_id
WHERE ur.user_id = 2;
```

### 4.2. Bảng `roles`: vai trò

**Mục đích:** danh sách các vai trò trong hệ thống.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | INT PK | Khóa chính |
| `code` | VARCHAR(30) UNIQUE | Mã vai trò: `guest`, `customer`, `staff`, `admin` |
| `name` | VARCHAR(100) | Tên hiển thị tiếng Việt |
| `description` | VARCHAR(255) | Mô tả |
| `is_system` | TINYINT(1) | 1 = vai trò hệ thống, không cho xóa |
| `created_at` | DATETIME | Thời điểm tạo |

**Điểm đặc biệt:** `guest` là **role logic**. Không user nào được gán role này. Khi request không có token đăng nhập, ứng dụng tự coi người đó là `guest` và nạp quyền của role này (xem sản phẩm, xem bài viết, quản lý giỏ).

### 4.3. Bảng `permissions`: quyền

**Mục đích:** danh mục mọi hành động có thể kiểm soát.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | INT PK | Khóa chính |
| `code` | VARCHAR(80) UNIQUE | Mã quyền `module.action` |
| `name` | VARCHAR(150) | Tên tiếng Việt |
| `module` | VARCHAR(40) | Nhóm chức năng: `catalog`, `order`, `inventory`, `system`... (có index để gom nhóm trên giao diện phân quyền) |
| `description` | VARCHAR(255) | Mô tả thêm |

**Quy ước hậu tố `_own`:** các quyền như `order.view_own`, `cart.manage_own` chỉ cho phép thao tác trên dữ liệu **của chính mình**. Database chỉ lưu "có quyền này", còn việc kiểm tra `user_id = người đang đăng nhập` do **ứng dụng** thực hiện (xem [mục 13](#13-việc-ứng-dụng-phải-tự-đảm-bảo)).

### 4.4. Bảng `role_permissions`: gán quyền cho vai trò

**Mục đích:** bảng trung gian N–N giữa `roles` và `permissions`.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `role_id` | INT, FK → `roles.id` | Vai trò |
| `permission_id` | INT, FK → `permissions.id` | Quyền |

- Khóa chính **kép** `(role_id, permission_id)`: một quyền không thể gán trùng cho một role.
- Xóa role hoặc permission thì dòng gán tự xóa theo (CASCADE).

### 4.5. Ma trận phân quyền mặc định (từ seed data)

| Mã quyền | Guest | Customer | Staff | Admin |
|---|:-:|:-:|:-:|:-:|
| `product.view` Xem sản phẩm | ✅ | ✅ | ✅ | ✅ |
| `article.view` Xem bài viết | ✅ | ✅ | ✅ | ✅ |
| `cart.manage_own` Quản lý giỏ hàng của mình | ✅ | ✅ | | ✅ |
| `profile.manage_own` Quản lý hồ sơ cá nhân | | ✅ | ✅ | ✅ |
| `address.manage_own` Quản lý địa chỉ giao hàng | | ✅ | | ✅ |
| `order.create` Đặt hàng | | ✅ | | ✅ |
| `order.view_own` Xem lịch sử đơn của mình | | ✅ | | ✅ |
| `order.cancel_own` Hủy đơn khi còn chờ xác nhận | | ✅ | | ✅ |
| `review.create` Đánh giá sản phẩm đã mua | | ✅ | | ✅ |
| `order.view_all` Xem tất cả đơn hàng | | | ✅ | ✅ |
| `order.update_status` Cập nhật trạng thái đơn | | | ✅ | ✅ |
| `inventory.view` Xem tồn kho và lô hàng | | | ✅ | ✅ |
| `inventory.manage` Nhập lô, điều chỉnh tồn, hủy hàng hết hạn | | | ✅ | ✅ |
| `review.moderate` Duyệt/ẩn đánh giá | | | ✅ | ✅ |
| `product.manage` Quản lý sản phẩm và biến thể | | | | ✅ |
| `category.manage` Quản lý danh mục | | | | ✅ |
| `price.manage` Cấu hình giá bán | | | | ✅ |
| `article.manage` Quản lý bài viết | | | | ✅ |
| `coupon.manage` Quản lý mã giảm giá | | | | ✅ |
| `report.view_revenue` Xem báo cáo doanh thu | | | | ✅ |
| `user.manage` Quản lý tài khoản khách hàng | | | | ✅ |
| `staff.manage` Quản lý nhân viên | | | | ✅ |
| `role.manage` Quản lý vai trò và phân quyền | | | | ✅ |

Gợi ý: nhân viên muốn tự mua hàng như khách thì gán thêm role `customer` cho tài khoản đó (bảng `user_roles` cho phép nhiều role).

### 4.6. Bảng `users`: tài khoản đăng nhập

**Mục đích:** lưu **mọi người có tài khoản**: khách hàng, nhân viên và admin đều nằm chung một bảng. Phân biệt bằng `user_roles`. Guest không có trong bảng này.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | Khóa chính |
| `email` | VARCHAR(191) UNIQUE | Email đăng nhập. Dùng 191 ký tự để index `utf8mb4` không vượt giới hạn độ dài khóa |
| `phone` | VARCHAR(20) UNIQUE, NULL | Số điện thoại (có thể chưa khai báo) |
| `password_hash` | VARCHAR(255) | **Chỉ lưu hash** (bcrypt/argon2), tuyệt đối không lưu mật khẩu gốc |
| `full_name` | VARCHAR(150) | Họ tên |
| `avatar_url` | VARCHAR(500) | Ảnh đại diện |
| `status` | ENUM | `pending` (chờ xác thực email), `active`, `inactive` (tạm khóa), `banned` (cấm) |
| `email_verified_at` | DATETIME | Thời điểm xác thực email; NULL nếu chưa |
| `last_login_at` | DATETIME | Lần đăng nhập gần nhất |
| `created_at`, `updated_at` | DATETIME | Tạo / cập nhật |
| `deleted_at` | DATETIME | **Xóa mềm**: khác NULL nghĩa là tài khoản đã bị xóa |

**Quan hệ:** 1–N với `user_roles`, `user_addresses`, `orders`, `reviews`, `loyalty_transactions`, `articles`; 1–1 với `customer_profiles`, `staff_profiles`, `carts`.

**Vì sao xóa mềm?** Đơn hàng, đánh giá, lịch sử kho đều trỏ về `users`. Xóa cứng sẽ phá dữ liệu kế toán và truy vết.

**Lưu ý:** `email` và `phone` là UNIQUE kể cả với tài khoản đã xóa mềm. Muốn cho người dùng đăng ký lại bằng email cũ, ứng dụng cần đổi email của tài khoản cũ (ví dụ thêm hậu tố) khi xóa.

### 4.7. Bảng `user_roles`: gán vai trò cho người dùng

**Mục đích:** bảng trung gian N–N giữa `users` và `roles`.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `user_id` | BIGINT, FK → `users.id` | Người dùng |
| `role_id` | INT, FK → `roles.id` | Vai trò |
| `assigned_by` | BIGINT, FK → `users.id`, NULL | Admin nào gán quyền này (NULL nếu tự động, ví dụ khách tự đăng ký) |
| `assigned_at` | DATETIME | Thời điểm gán |

- Khóa chính kép `(user_id, role_id)`; thêm index theo `role_id` để truy vấn "liệt kê mọi nhân viên".
- Vì N–N nên một người có thể vừa là `staff` vừa là `customer`.

### 4.8. Bảng `customer_profiles`: hồ sơ riêng của khách hàng

**Mục đích:** tách thông tin chỉ khách hàng mới có ra khỏi `users`, để `users` gọn và không dính các cột vô nghĩa với nhân viên.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `user_id` | BIGINT **PK** + FK → `users.id` | Vừa là khóa chính vừa là khóa ngoại, đảm bảo quan hệ **1–1** |
| `gender` | ENUM | `male`, `female`, `other` |
| `birth_date` | DATE | Ngày sinh (dùng cho ưu đãi sinh nhật) |
| `loyalty_points` | INT UNSIGNED | **Số dư điểm tích lũy hiện tại** |
| `loyalty_tier` | ENUM | Hạng thành viên: `standard`, `silver`, `gold`, `vip` |
| `total_spent` | DECIMAL(14,0) | Tổng tiền đã chi (dùng để xét lên hạng) |
| `marketing_opt_in` | TINYINT(1) | Có đồng ý nhận tin khuyến mãi không |

`loyalty_points` là số dư lưu sẵn để đọc nhanh; lịch sử chi tiết nằm ở `loyalty_transactions`.

### 4.9. Bảng `staff_profiles`: hồ sơ riêng của nhân viên

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `user_id` | BIGINT **PK** + FK → `users.id` | Quan hệ 1–1 |
| `employee_code` | VARCHAR(20) UNIQUE | Mã nhân viên (`EMP001`...) |
| `position` | VARCHAR(100) | Chức danh: nhân viên sơ chế, nhân viên kho... |
| `hired_at` | DATE | Ngày vào làm |
| `is_active` | TINYINT(1) | Còn làm việc không (nghỉ việc thì đặt 0 thay vì xóa, giữ nguyên lịch sử xử lý đơn) |

### 4.10. Bảng `user_addresses`: sổ địa chỉ giao hàng

**Mục đích:** mỗi khách có thể lưu nhiều địa chỉ (nhà riêng, công ty...).

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | Khóa chính |
| `user_id` | BIGINT FK → `users.id` | Chủ địa chỉ |
| `label` | VARCHAR(50) | Nhãn: "Nhà riêng", "Công ty" |
| `recipient_name`, `recipient_phone` | VARCHAR | Người nhận (có thể khác chủ tài khoản) |
| `province`, `ward` | VARCHAR(100) NOT NULL | Tỉnh/thành phố, phường/xã |
| `district` | VARCHAR(100) **NULL** | Quận/huyện. Cho phép NULL vì địa giới hành chính hiện không còn cấp huyện |
| `address_line` | VARCHAR(255) | Số nhà, tên đường |
| `is_default` | TINYINT(1) | Địa chỉ mặc định |
| `created_at`, `updated_at` | DATETIME | |

- Index `(user_id, is_default)` để lấy nhanh địa chỉ mặc định của khách.
- Database **không** tự đảm bảo mỗi user chỉ có một địa chỉ mặc định; ứng dụng phải bỏ cờ `is_default` của địa chỉ cũ khi đặt địa chỉ mới.
- Khi đặt hàng, địa chỉ được **sao chép** sang `orders` (snapshot). Khách sửa hoặc xóa địa chỉ sau đó không ảnh hưởng đơn cũ.

### 4.11. Bảng `loyalty_transactions`: sổ cái điểm tích lũy

**Mục đích:** ghi lại mỗi lần cộng/trừ điểm. Đây là nguồn đối chiếu cho `customer_profiles.loyalty_points`.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `user_id` | BIGINT FK → `users.id` | Chủ điểm |
| `order_id` | BIGINT FK → `orders.id`, NULL | Đơn hàng liên quan (NULL nếu điều chỉnh tay) |
| `type` | ENUM | `earn` (tích), `redeem` (đổi), `adjust` (điều chỉnh), `expire` (hết hạn), `refund` (hoàn điểm khi hủy đơn) |
| `points` | INT **có dấu** | `+58` là cộng, `-20` là trừ |
| `balance_after` | INT UNSIGNED | Số dư **sau** giao dịch này, giúp tra cứu nhanh mà không phải cộng dồn |
| `note` | VARCHAR(255) | Ghi chú |
| `created_by` | BIGINT FK → `users.id`, NULL | Ai điều chỉnh (NULL nếu hệ thống tự động) |
| `created_at` | DATETIME | |

Index `(user_id, created_at)` phục vụ trang "Lịch sử điểm" của khách.

**Quy tắc điểm trong seed:** 1 điểm cho mỗi 10.000đ của đơn (đơn 580.000đ được 58 điểm). Quy tắc quy đổi cụ thể là do ứng dụng quyết định.

---
## 5. Nhóm 2: Danh mục và sản phẩm (Catalog)

Gồm 6 bảng: `categories`, `products`, `product_images`, `product_variants`, `combo_items`, `price_histories`.

### 5.1. Mô hình 3 tầng: Danh mục → Sản phẩm → Biến thể

```
categories (Lươn tươi sống)
  └── products (Lươn đồng sống loại 1)          ← thứ khách "xem" trên trang
        └── product_variants (Bán theo kg)       ← thứ khách "mua", có giá và tồn kho
```

| Tầng | Bảng | Trả lời câu hỏi | Ví dụ |
|---|---|---|---|
| 1 | `categories` | Hàng thuộc nhóm nào? | Lươn tươi sống; Lươn sơ chế; Combo |
| 2 | `products` | Đây là món gì? (tên, mô tả, ảnh, xuất xứ) | Lươn đồng sơ chế làm sạch |
| 3 | `product_variants` | Mua loại nào, giá bao nhiêu? | Túi 500g (135.000đ), Túi 1kg (255.000đ) |

**Vì sao tách biến thể?** Cùng một sản phẩm "Lươn đồng sơ chế" có nhiều quy cách khác giá, khác SKU, khác tồn kho. Giỏ hàng, đơn hàng, lô kho đều trỏ về **biến thể**, không phải sản phẩm.

### 5.2. Bảng `categories`: danh mục

**Mục đích:** cây danh mục hai cấp (hoặc nhiều cấp) cho menu và bộ lọc.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | INT PK | |
| `parent_id` | INT FK → `categories.id`, NULL | Danh mục cha; NULL nghĩa là danh mục gốc |
| `name` | VARCHAR(150) | Tên hiển thị |
| `slug` | VARCHAR(180) UNIQUE | Đường dẫn thân thiện URL (`luon-tuoi-song`) |
| `description`, `image_url` | | Mô tả, ảnh đại diện |
| `sort_order` | INT | Thứ tự hiển thị |
| `is_active` | TINYINT(1) | Ẩn/hiện |

**Quan hệ tự tham chiếu:** `parent_id` trỏ về chính bảng này. Ví dụ "Lươn đóng hộp" (id 4) và "Lươn hút chân không" (id 5) đều có `parent_id = 3` ("Lươn chế biến sẵn").

Index `(parent_id, sort_order)` để dựng menu cây đúng thứ tự.

### 5.3. Bảng `products`: sản phẩm

**Mục đích:** thông tin mô tả sản phẩm hiển thị trên website. Bảng **không có giá**: giá nằm ở biến thể.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `category_id` | INT FK → `categories.id` | Thuộc danh mục nào (mỗi sản phẩm một danh mục) |
| `name` | VARCHAR(200) | Tên sản phẩm |
| `slug` | VARCHAR(220) UNIQUE | URL thân thiện |
| `short_description` | VARCHAR(500) | Mô tả ngắn cho thẻ sản phẩm |
| `description` | MEDIUMTEXT | Mô tả chi tiết |
| `thumbnail_url` | VARCHAR(500) | Ảnh đại diện |
| `origin` | VARCHAR(150) | Vùng nuôi / xuất xứ (rất quan trọng với thực phẩm tươi sống) |
| `search_keywords` | VARCHAR(500) | **Từ khóa không dấu** để tìm kiếm (ví dụ "luon dong song loai 1 eel live") |
| `status` | ENUM | `draft` (nháp), `active` (đang bán), `hidden` (ẩn), `discontinued` (ngừng kinh doanh) |
| `is_featured` | TINYINT(1) | Nổi bật trang chủ |
| `avg_rating` | DECIMAL(3,2) | Điểm đánh giá trung bình (**lưu sẵn**) |
| `review_count` | INT UNSIGNED | Số đánh giá (**lưu sẵn**) |
| `created_by` | BIGINT FK → `users.id` | Người tạo |
| `created_at`, `updated_at` | DATETIME | |

**Tối ưu tìm kiếm sản phẩm lươn:**

- `FULLTEXT KEY ft_products_search (name, search_keywords, short_description)`: tìm nhanh theo từ khóa.
- Vấn đề tiếng Việt có dấu/không dấu: người dùng gõ "luon song" nhưng tên lưu "Lươn sống". Giải pháp là cột `search_keywords` chứa dạng **không dấu**; ứng dụng bỏ dấu câu truy vấn trước khi tìm và tự sinh `search_keywords` khi lưu sản phẩm.
- Index `(category_id, status)`: lọc sản phẩm đang bán theo danh mục. Index `(is_featured, status)`: lấy sản phẩm nổi bật trang chủ.

**Dữ liệu lưu sẵn:** `avg_rating`, `review_count` được tính từ `reviews` (chỉ tính review `approved`) và cập nhật mỗi khi duyệt hoặc ẩn đánh giá, để trang danh sách không phải tính lại mỗi lần.

### 5.4. Bảng `product_images`: thư viện ảnh

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `product_id` | BIGINT FK → `products.id` | Ảnh của sản phẩm nào (CASCADE khi xóa sản phẩm) |
| `url` | VARCHAR(500) | Đường dẫn ảnh |
| `alt_text` | VARCHAR(200) | Văn bản thay thế (SEO, người khiếm thị) |
| `sort_order` | INT | Thứ tự trong thư viện |
| `is_primary` | TINYINT(1) | Ảnh chính |

### 5.5. Bảng `product_variants`: biến thể (trung tâm của hệ thống bán hàng)

**Mục đích:** mỗi dòng là **một thứ cụ thể có thể bán**, có SKU, giá, quy tắc đặt số lượng, hạn dùng mặc định.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `product_id` | BIGINT FK → `products.id` | Thuộc sản phẩm nào |
| `sku` | VARCHAR(50) UNIQUE | Mã quản lý kho (`LSD-L1-KG`) |
| `name` | VARCHAR(150) | Tên quy cách: "Bán theo kg", "Túi 500g" |
| `variant_type` | ENUM | `live` (sống), `fresh_processed` (sơ chế tươi), `canned` (đóng hộp), `vacuum_pack` (hút chân không), `combo`, `condiment` (gia vị) |
| `unit` | ENUM | Đơn vị bán: `kg`, `pack` (túi), `can` (hộp), `combo`, `piece` |
| `weight_grams` | INT UNSIGNED | Khối lượng của **một đơn vị** (kg = 1000, túi 500g = 500). Dùng để tính phí vận chuyển |
| `price` | DECIMAL(12,0) | **Giá niêm yết cho một đơn vị** (VND) |
| `sale_price` | DECIMAL(12,0) NULL | Giá khuyến mãi; NULL nghĩa là không giảm |
| `min_order_qty` | DECIMAL(10,3) | Số lượng đặt tối thiểu (lươn sống: 0.5 kg) |
| `qty_step` | DECIMAL(10,3) | **Bước nhảy số lượng** (lươn sống: 0.5; hàng đóng gói: 1) |
| `max_order_qty` | DECIMAL(10,3) NULL | Số lượng tối đa mỗi đơn |
| `shelf_life_days` | SMALLINT UNSIGNED NULL | Hạn dùng mặc định (ngày), dùng gợi ý `expiry_date` khi nhập lô |
| `requires_cold_chain` | TINYINT(1) | Cần giữ lạnh khi vận chuyển (ảnh hưởng đóng gói, chọn shipper) |
| `storage_instructions` | VARCHAR(300) | Hướng dẫn bảo quản hiển thị cho khách |
| `is_active` | TINYINT(1) | Đang bán |
| `sort_order` | INT | Thứ tự hiển thị |
| `created_at`, `updated_at` | DATETIME | |

**Ràng buộc CHECK:**
- `price >= 0`
- `sale_price IS NULL OR sale_price <= price` (giá khuyến mãi không được cao hơn giá gốc)
- `min_order_qty > 0 AND qty_step > 0`

**Giải quyết "lươn bán theo kg, còn đồ đóng gói bán theo cái":**

| Loại hàng | `unit` | `min_order_qty` | `qty_step` | Ý nghĩa |
|---|---|---|---|---|
| Lươn sống | `kg` | 0.500 | 0.500 | Mua 0.5kg, 1kg, 1.5kg... |
| Lươn sơ chế túi 500g | `pack` | 1.000 | 1.000 | Mua 1, 2, 3 túi |
| Lươn đóng hộp | `can` | 1.000 | 1.000 | Mua 1, 2, 3 hộp |

Ứng dụng kiểm tra `(quantity - min_order_qty) % qty_step = 0` trước khi cho vào giỏ.

**Các index:**
- `(product_id, is_active)`: lấy các quy cách đang bán của một sản phẩm.
- `(variant_type, is_active)`: lọc theo loại ("chỉ xem lươn sống", "chỉ xem đồ đóng hộp").
- `(price)`: lọc/sắp xếp theo khoảng giá.

### 5.6. Bảng `combo_items`: thành phần của combo

**Mục đích:** một biến thể loại `combo` gồm những biến thể nào, số lượng bao nhiêu.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `combo_variant_id` | BIGINT FK → `product_variants.id` | Biến thể là combo |
| `component_variant_id` | BIGINT FK → `product_variants.id` | Biến thể thành phần |
| `quantity` | DECIMAL(10,3) | Số lượng thành phần trong **một** combo |

Khóa chính kép `(combo_variant_id, component_variant_id)`. Đây là **quan hệ tự tham chiếu N–N** của `product_variants`.

Ví dụ trong seed:

| Combo | Thành phần | Số lượng |
|---|---|---|
| `CB-MIENLUON` (Combo miến lươn) | `LSC-SACH-500G` (lươn sơ chế 500g) | 1 |
| `CB-MIENLUON` | `GV-MIENLUON-50G` (gói gia vị) | 2 |
| `CB-LUONXAO` (Combo lươn xào lăn) | `LSD-L1-KG` (lươn sống loại 1) | 1 |
| `CB-LUONXAO` | `GV-MIENLUON-50G` | 2 |

**Nguyên tắc tồn kho combo:** combo **không có lô riêng**. Khi bán 1 combo, hệ thống trừ tồn của từng thành phần theo FEFO. Do đó view `v_variant_available_stock` loại combo ra, còn tồn khả dụng của combo được tính bằng `MIN(tồn thành phần / số lượng thành phần)`.

### 5.7. Bảng `price_histories`: lịch sử đổi giá

**Mục đích:** khi admin đổi giá, ghi lại giá cũ, giá mới, người đổi, lý do. Phục vụ kiểm toán, phân tích biến động giá lươn theo mùa.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `variant_id` | BIGINT FK → `product_variants.id` | Biến thể bị đổi giá |
| `old_price`, `new_price` | DECIMAL(12,0) | Giá gốc cũ / mới |
| `old_sale_price`, `new_sale_price` | DECIMAL(12,0) NULL | Giá khuyến mãi cũ / mới |
| `changed_by` | BIGINT FK → `users.id` NOT NULL | Ai đổi (bắt buộc, truy vết) |
| `reason` | VARCHAR(255) | Lý do ("Giá lươn đồng tăng theo thị trường") |
| `created_at` | DATETIME | |

Index `(variant_id, created_at)` để xem biểu đồ giá theo thời gian của một biến thể. Quyền thay đổi giá: `price.manage` (chỉ admin).

---

## 6. Nhóm 3: Kho theo lô (Inventory)

Gồm 3 bảng: `suppliers`, `inventory_batches`, `inventory_transactions`.

### 6.1. Vì sao quản lý theo lô?

Lươn sống và lươn sơ chế có hạn dùng chỉ từ 2–3 ngày. Nếu chỉ lưu "tồn kho = 100kg" thì không biết:
- Bao nhiêu trong đó sắp hết hạn?
- Khi bán thì nên xuất phần nào trước?
- Nếu một lô có vấn đề thì đơn nào đã dùng lô đó?

Quản lý theo lô giải quyết cả ba. **Tồn kho của một biến thể = tổng `quantity_remaining` của các lô còn hạn.** Không có cột "tồn kho" nằm trực tiếp ở `product_variants`.

### 6.2. Bảng `suppliers`: nhà cung cấp

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | INT PK | |
| `name` | VARCHAR(200) | Tên nhà cung cấp |
| `supplier_type` | ENUM | `farm` (trại nuôi), `processor` (cơ sở chế biến), `condiment_vendor` (nhà cung cấp gia vị) |
| `contact_name`, `phone`, `email`, `address` | | Liên hệ |
| `is_active` | TINYINT(1) | |
| `created_at` | DATETIME | |

Dùng để truy xuất nguồn gốc: lô này nhập từ trại nào.

### 6.3. Bảng `inventory_batches`: lô hàng

**Mục đích:** mỗi lần nhập hàng tạo **một lô**. Lô là đơn vị theo dõi tồn kho và hạn dùng.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `batch_code` | VARCHAR(50) UNIQUE | Mã lô (`LOT-LSD1-20261119-A`: loại hàng, ngày nhập, thứ tự) |
| `variant_id` | BIGINT FK → `product_variants.id` | Lô này chứa biến thể nào |
| `supplier_id` | INT FK → `suppliers.id`, NULL | Nhập từ đâu |
| `received_by` | BIGINT FK → `users.id`, NULL | Nhân viên nhận hàng |
| `storage_condition` | ENUM | `live_tank` (bể nuôi sống), `chilled` (mát), `frozen` (đông), `ambient` (nhiệt độ thường) |
| `produced_date` | DATE NULL | Ngày sản xuất/sơ chế (lươn sống thì NULL) |
| `received_date` | DATE | **Ngày nhập** |
| `expiry_date` | DATE | **Ngày hết hạn / hạn bán** |
| `quantity_received` | DECIMAL(12,3) | Số lượng nhập ban đầu |
| `quantity_remaining` | DECIMAL(12,3) | Số lượng còn lại |
| `unit_cost` | DECIMAL(12,0) | Giá vốn một đơn vị (tính lãi gộp) |
| `status` | ENUM | `available` (bán được), `quarantine` (cách ly kiểm tra), `expired` (hết hạn), `depleted` (hết hàng), `discarded` (đã tiêu hủy) |
| `note` | VARCHAR(300) | |
| `created_at`, `updated_at` | DATETIME | |

**Ràng buộc CHECK:**
- `quantity_received >= 0 AND quantity_remaining >= 0 AND quantity_remaining <= quantity_received`: không âm, không vượt số nhập.
- `expiry_date >= received_date`: hạn dùng không thể trước ngày nhập.

**Index quan trọng nhất của kho: `idx_batch_fefo (variant_id, status, expiry_date)`**
Phục vụ truy vấn chọn lô xuất kho: "lấy các lô còn bán được của biến thể X, sắp theo hạn tăng dần". Một index duy nhất phủ cả điều kiện lọc lẫn sắp xếp.

**Chiến lược FEFO (First Expired, First Out):** hết hạn trước, xuất trước (khác FIFO là nhập trước xuất trước):

```sql
SELECT id, batch_code, expiry_date, quantity_remaining
FROM inventory_batches
WHERE variant_id = 1 AND status = 'available'
  AND expiry_date >= CURDATE() AND quantity_remaining > 0
ORDER BY expiry_date ASC, id ASC
FOR UPDATE;   -- khóa dòng để hai đơn cùng lúc không bán vượt tồn
```

Các index khác: `(expiry_date, status)` cho job quét lô sắp hết hạn; `(supplier_id)` cho báo cáo theo nhà cung cấp.

**Lưu ý vận hành:** cột `status` không tự đổi sang `expired`. Cần job định kỳ (cron/event) cập nhật. Dù job chưa chạy thì view tồn kho và truy vấn FEFO vẫn lọc thêm `expiry_date >= CURDATE()` nên không bán nhầm hàng hết hạn.

### 6.4. Bảng `inventory_transactions`: sổ cái kho

**Mục đích:** ghi **mọi biến động** của từng lô. Cộng toàn bộ `quantity_change` của một lô sẽ ra `quantity_remaining`.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `batch_id` | BIGINT FK → `inventory_batches.id` | Lô bị biến động |
| `type` | ENUM | Loại biến động (bảng dưới) |
| `quantity_change` | DECIMAL(12,3) **có dấu** | `+` là nhập vào, `-` là xuất ra |
| `order_id` | BIGINT FK → `orders.id`, NULL | Đơn hàng liên quan (nếu là bán/hoàn) |
| `performed_by` | BIGINT FK → `users.id`, NULL | Nhân viên thao tác; NULL nghĩa là hệ thống tự động |
| `note` | VARCHAR(300) | Ghi chú |
| `created_at` | DATETIME | |

| `type` | Dấu | Khi nào |
|---|:-:|---|
| `receive` | + | Nhập lô mới |
| `sale` | − | Bán cho khách (gắn `order_id`) |
| `cancel_restore` | + | Hoàn kho khi hủy đơn |
| `wastage` | − | Hao hụt: lươn chết trong bể, hỏng khi sơ chế |
| `adjust` | ± | Điều chỉnh sau kiểm kê |
| `expire_discard` | − | Tiêu hủy hàng hết hạn |

Index `(batch_id, created_at)`: lịch sử một lô; `(order_id)`: xem đơn đã trừ kho thế nào; `(type, created_at)`: báo cáo hao hụt theo thời gian.

**Kiểm tra lệch số:**

```sql
SELECT b.id, b.quantity_remaining AS luu_san, SUM(t.quantity_change) AS tu_so_cai
FROM inventory_batches b
JOIN inventory_transactions t ON t.batch_id = b.id
GROUP BY b.id, b.quantity_remaining
HAVING luu_san <> tu_so_cai;
```

---

## 7. Nhóm 4: Giỏ hàng (Cart)

Gồm 2 bảng: `carts`, `cart_items`.

### 7.1. Một bảng giỏ cho cả hai loại khách

```
Guest:     carts(user_id = NULL, guest_token = 'gst_7f3a...')
Customer:  carts(user_id = 6,    guest_token = NULL)
```

- Guest được cấp `guest_token` (chuỗi ngẫu nhiên đủ dài) lưu ở cookie **HttpOnly** ngay lần đầu thêm hàng.
- Khách đã đăng nhập dùng `user_id`.

### 7.2. Bảng `carts`

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `user_id` | BIGINT FK → `users.id`, **UNIQUE**, NULL | Chủ giỏ nếu đã đăng nhập; NULL với guest |
| `guest_token` | VARCHAR(64) **UNIQUE**, NULL | Mã nhận diện guest |
| `status` | ENUM | `active` (đang dùng), `merged` (đã gộp vào giỏ khác), `abandoned` (bỏ quên) |
| `merged_into_cart_id` | BIGINT FK → `carts.id`, NULL | Giỏ guest này đã được gộp vào giỏ nào (truy vết) |
| `merged_at` | DATETIME | Thời điểm gộp |
| `expires_at` | DATETIME | Hạn của giỏ guest để job dọn rác |
| `last_activity_at` | DATETIME | Lần thao tác cuối (nhận diện giỏ bị bỏ quên) |
| `created_at`, `updated_at` | DATETIME | |

**Ba ràng buộc quan trọng:**

| Ràng buộc | Tác dụng |
|---|---|
| `UNIQUE(user_id)` | Mỗi khách hàng chỉ có **một** giỏ. MySQL cho phép nhiều giá trị NULL trong cột UNIQUE nên nhiều giỏ guest (user_id = NULL) vẫn hợp lệ |
| `UNIQUE(guest_token)` | Mỗi guest một giỏ; tương tự, giỏ của customer (token = NULL) không xung đột nhau |
| `CHECK (user_id IS NOT NULL OR guest_token IS NOT NULL)` | Giỏ phải có chủ, không tồn tại "giỏ vô danh" |

**Lưu ý:** khi gộp xong, giỏ guest chuyển `status = 'merged'` nhưng vẫn giữ `guest_token`. Nếu trình duyệt gửi lại token cũ, ứng dụng thấy giỏ đã `merged` thì cấp token mới cho lần thêm hàng tiếp theo.

### 7.3. Bảng `cart_items`

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `cart_id` | BIGINT FK → `carts.id` | Thuộc giỏ nào (CASCADE khi xóa giỏ) |
| `variant_id` | BIGINT FK → `product_variants.id` | Biến thể được thêm |
| `quantity` | DECIMAL(10,3) | Số lượng (CHECK > 0) |
| `added_at`, `updated_at` | DATETIME | |

- `UNIQUE(cart_id, variant_id)`: mỗi biến thể chỉ xuất hiện **một dòng** trong giỏ; thêm lần nữa thì cộng dồn `quantity` bằng `INSERT ... ON DUPLICATE KEY UPDATE`.
- **Giỏ hàng không lưu giá.** Giá luôn lấy từ `product_variants` tại thời điểm xem/đặt, nên khách luôn thấy giá hiện tại. Giá chỉ được chốt khi tạo `order_items`.
- Giỏ hàng **không** giữ tồn kho. Tồn kho chỉ bị trừ khi đặt hàng thành công.

### 7.4. Luồng gộp giỏ khi guest đăng nhập

Thực hiện bằng stored procedure `sp_merge_guest_cart(guest_token, user_id)` (xem [mục 10.2](#102-stored-procedure-sp_merge_guest_cart)):

```
Trước:  Giỏ guest #1 {Lươn sống 0.5kg, Gia vị x1}     Giỏ user #2 {Chiên giòn x1, Lươn sống 0.5kg}
Sau:    Giỏ guest #1 → status='merged', rỗng            Giỏ user #2 {Chiên giòn x1, Lươn sống 1.0kg, Gia vị x1}
                       merged_into_cart_id = 2
```

---
## 8. Nhóm 5: Đơn hàng (Ordering)

Gồm 5 bảng: `coupons`, `orders`, `order_items`, `order_item_batches`, `order_status_histories`.

### 8.1. Bảng `coupons`: mã giảm giá

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | INT PK | |
| `code` | VARCHAR(40) UNIQUE | Mã khách nhập (`WELCOME10`) |
| `description` | VARCHAR(255) | Mô tả hiển thị |
| `discount_type` | ENUM | `percent` (giảm theo %) hoặc `fixed` (giảm số tiền cố định) |
| `discount_value` | DECIMAL(12,2) | Giá trị: 10 nghĩa là 10% hoặc 30.000 đồng, tùy `discount_type` |
| `min_order_amount` | DECIMAL(12,0) | Đơn tối thiểu để áp dụng |
| `max_discount_amount` | DECIMAL(12,0) NULL | Mức giảm tối đa (hay dùng với loại phần trăm) |
| `usage_limit` | INT UNSIGNED NULL | Tổng số lần dùng tối đa; NULL là không giới hạn |
| `used_count` | INT UNSIGNED | Đã dùng bao nhiêu lần |
| `starts_at`, `ends_at` | DATETIME NULL | Thời gian hiệu lực |
| `is_active` | TINYINT(1) | Bật/tắt thủ công |
| `created_by` | BIGINT FK → `users.id` | Admin tạo mã |
| `created_at` | DATETIME | |

Quyền quản lý: `coupon.manage` (admin). Đơn hàng trỏ về coupon qua `orders.coupon_id`.

### 8.2. Bảng `orders`: đơn hàng

**Mục đích:** bản ghi trung tâm của một giao dịch mua. Gồm: ai mua, giao đi đâu, tiền bao nhiêu, đang ở bước nào, nhân viên nào phụ trách.

Chỉ **khách đã đăng nhập** mới đặt hàng được, nên `user_id` là NOT NULL.

#### Nhóm cột định danh và người mua

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `order_code` | VARCHAR(30) UNIQUE | Mã đơn hiển thị cho khách (`EEL-20261120-0001`) |
| `user_id` | BIGINT FK → `users.id` NOT NULL | Khách đặt |

#### Nhóm cột trạng thái và xử lý

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `status` | ENUM | Trạng thái chính: `pending` (chờ xác nhận), `processing` (đang sơ chế/đóng gói), `shipping` (đang giao), `completed` (hoàn thành), `cancelled` (hủy) |
| `processing_step` | ENUM NULL | Bước con khi `status = processing`: `preparing_eel` (đang sơ chế lươn), `packing` (đang đóng gói) |
| `assigned_staff_id` | BIGINT FK → `users.id`, NULL | **Nhân viên đang phụ trách đơn** |

**Vì sao 5 trạng thái chính + 1 bước con?** Quy trình nghiệp vụ gốc có 5 trạng thái. Việc "đang sơ chế lươn" và "đang đóng gói" đều thuộc trạng thái "Đang sơ chế" nên được tách thành `processing_step` để giữ vòng đời đơn đơn giản mà vẫn cho nhân viên cập nhật chi tiết.

**Ràng buộc:** `CHECK (processing_step IS NULL OR status = 'processing')`. Khi chuyển sang `shipping`, `completed` hay `cancelled`, ứng dụng **phải đặt `processing_step = NULL`**, nếu không database sẽ từ chối lệnh UPDATE.

#### Nhóm cột địa chỉ giao hàng (snapshot)

`recipient_name`, `recipient_phone`, `shipping_province`, `shipping_district` (NULL được), `shipping_ward`, `shipping_address_line`, `customer_note`.
Đây là **bản sao** từ `user_addresses` lúc đặt, không dùng khóa ngoại tới sổ địa chỉ để đơn cũ không bị đổi khi khách sửa địa chỉ.

#### Nhóm cột tiền

| Cột | Ý nghĩa |
|---|---|
| `subtotal` | Tổng tiền hàng = tổng `line_total` các dòng |
| `discount_amount` | Giảm do mã giảm giá |
| `points_used` | Số điểm khách dùng |
| `points_discount` | Số tiền quy đổi từ điểm |
| `shipping_fee` | Phí vận chuyển |
| `total_amount` | **Khách phải trả** |
| `points_earned` | Điểm sẽ được cộng khi đơn hoàn thành |
| `coupon_id` | Mã giảm giá đã dùng (FK → `coupons.id`) |

**Công thức:** `total_amount = subtotal − discount_amount − points_discount + shipping_fee`

Ví dụ đơn `EEL-20261120-0001`: 300.000 − 30.000 + 35.000 = 305.000.

#### Nhóm cột thanh toán

| Cột | Ý nghĩa |
|---|---|
| `payment_method` | `cod` (thu tiền khi giao), `bank_transfer`, `momo`, `vnpay` |
| `payment_status` | `unpaid`, `paid`, `refunded` |
| `paid_at` | Thời điểm thanh toán |

#### Nhóm cột giao hàng và hủy

| Cột | Ý nghĩa |
|---|---|
| `shipper_name`, `shipper_phone`, `tracking_code` | Thông tin shipper và mã vận đơn (nhân viên điền khi giao cho shipper) |
| `cancel_reason`, `cancelled_by` | Lý do hủy và người hủy (khách hay nhân viên) |

#### Nhóm mốc thời gian

`placed_at` (đặt), `confirmed_at` (nhân viên tiếp nhận, chuyển sang `processing`), `shipped_at` (giao cho shipper), `completed_at` (hoàn thành), `cancelled_at` (hủy), `updated_at`.

#### Index của `orders`

| Index | Phục vụ |
|---|---|
| `(user_id, placed_at)` | Trang "Đơn hàng của tôi", mới nhất trước |
| `(status, placed_at)` | Màn hình nhân viên: danh sách đơn chờ xác nhận / đang xử lý |
| `(assigned_staff_id, status)` | "Đơn tôi đang phụ trách" |
| `(payment_status)` | Lọc đơn chưa thanh toán |
| `(completed_at)` | Báo cáo doanh thu theo ngày |

### 8.3. Vòng đời đơn hàng

```
                      ┌────────────── Khách / Nhân viên / Admin hủy ──────────────┐
                      ▼                                                           │
 [pending] ──nhân viên tiếp nhận──► [processing] ──giao shipper──► [shipping] ──► [completed]
 Chờ xác nhận                        ├─ preparing_eel (sơ chế)     Đang giao       Hoàn thành
                                     └─ packing (đóng gói)
                                                                                  [cancelled]
                                                                                  Đã hủy
```

| Chuyển trạng thái | Ai thực hiện | Cập nhật cột |
|---|---|---|
| (tạo mới) → `pending` | Khách | `placed_at`, `status = pending` |
| `pending` → `processing` (`preparing_eel`) | Staff | `assigned_staff_id`, `confirmed_at`, `processing_step` |
| `preparing_eel` → `packing` | Staff | `processing_step = packing` |
| `processing` → `shipping` | Staff | `processing_step = NULL`, `shipped_at`, thông tin shipper |
| `shipping` → `completed` | Staff | `completed_at`, `payment_status = paid` (với COD) |
| `pending` → `cancelled` | Khách (quyền `order.cancel_own`) hoặc Staff | `cancelled_at`, `cancelled_by`, `cancel_reason` |
| `processing` → `cancelled` | Staff/Admin | như trên |

Mỗi lần chuyển đều ghi một dòng vào `order_status_histories`. Quy tắc "chỉ cho hủy khi chưa giao" là khuyến nghị nghiệp vụ, ứng dụng cần kiểm tra thứ tự chuyển hợp lệ.

### 8.4. Bảng `order_items`: dòng chi tiết đơn

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `order_id` | BIGINT FK → `orders.id` | Thuộc đơn nào (CASCADE) |
| `variant_id` | BIGINT FK → `product_variants.id` | Mua biến thể nào (để thống kê, hoàn kho) |
| `product_name`, `variant_name`, `sku`, `unit` | VARCHAR | **Snapshot** lúc mua |
| `quantity` | DECIMAL(10,3) | Số lượng (CHECK > 0) |
| `unit_price` | DECIMAL(12,0) | **Đơn giá đã chốt** (nếu lúc đó có `sale_price` thì lấy giá khuyến mãi) |
| `line_total` | DECIMAL(12,0) | Thành tiền = `quantity × unit_price` |

Vì sao lưu cả `variant_id` lẫn snapshot? `variant_id` để liên kết thống kê; snapshot để hiển thị đúng thông tin cũ dù sản phẩm đã đổi tên, đổi giá hoặc ngừng bán.

### 8.5. Bảng `order_item_batches`: đơn nào dùng lô nào

**Mục đích:** truy xuất nguồn gốc. Khi một lô có vấn đề (ví dụ nhiễm khuẩn), truy ngược ra mọi đơn đã nhận lô đó để liên hệ khách.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `order_item_id` | BIGINT FK → `order_items.id` | Dòng hàng (CASCADE) |
| `batch_id` | BIGINT FK → `inventory_batches.id` | Lô đã xuất |
| `quantity` | DECIMAL(12,3) | Lấy bao nhiêu từ lô này |

- `UNIQUE(order_item_id, batch_id)`.
- Một dòng hàng có thể lấy từ **nhiều lô** (ví dụ cần 5kg nhưng lô gần hết hạn chỉ còn 3kg thì lấy 3kg lô này và 2kg lô kế tiếp theo FEFO).
- Với dòng hàng là **combo**, bảng ghi các lô của **biến thể thành phần** (xem dòng 5 trong seed: combo miến lươn trỏ tới lô lươn sơ chế và lô gia vị).

**Truy ngược khi một lô có vấn đề:**

```sql
SELECT DISTINCT o.order_code, o.recipient_name, o.recipient_phone
FROM order_item_batches oib
JOIN order_items oi ON oi.id = oib.order_item_id
JOIN orders o       ON o.id = oi.order_id
WHERE oib.batch_id = 4;
```

### 8.6. Bảng `order_status_histories`: nhật ký xử lý đơn

**Mục đích:** đáp ứng yêu cầu **"lưu vết nhân viên nào xử lý đơn hàng"**. Mỗi lần đổi trạng thái hoặc đổi bước con là một dòng mới.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `order_id` | BIGINT FK → `orders.id` | Đơn nào (CASCADE) |
| `from_status` | ENUM NULL | Trạng thái trước (NULL ở dòng đầu tiên lúc tạo đơn) |
| `to_status` | ENUM NOT NULL | Trạng thái sau |
| `processing_step` | ENUM NULL | Bước con tại thời điểm đó |
| `changed_by` | BIGINT FK → `users.id`, NULL | Người thực hiện: nhân viên, khách (khi tự hủy) hoặc NULL nếu hệ thống tự động |
| `note` | VARCHAR(500) | Ghi chú ("Giao cho shipper Hoàng Văn Bình") |
| `created_at` | DATETIME | Thời điểm |

Một đơn mẫu (đơn `EEL-20261119-0001`) trong seed có 5 dòng lịch sử:

| Thời điểm | Từ → Đến | Bước | Người | Ghi chú |
|---|---|---|---|---|
| 09:12 | NULL → `pending` | | Khách (id 4) | Khách đặt hàng |
| 09:30 | `pending` → `processing` | `preparing_eel` | Staff (id 2) | Bắt đầu sơ chế lươn |
| 10:30 | `processing` → `processing` | `packing` | Staff (id 2) | Đổi bước con, `from` và `to` giống nhau |
| 11:00 | `processing` → `shipping` | | Staff (id 3) | Giao cho shipper |
| 16:20 | `shipping` → `completed` | | Staff (id 3) | Giao thành công, đã thu COD |

Index `(order_id, created_at)` để dựng timeline đơn; `(changed_by, created_at)` để thống kê **năng suất từng nhân viên**.

---

## 9. Nhóm 6: Đánh giá và bài viết

### 9.1. Bảng `reviews`: đánh giá sản phẩm

**Mục đích:** khách chấm sao và nhận xét sau khi mua. Chỉ nhận đánh giá từ người **đã mua thật**.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `user_id` | BIGINT FK → `users.id` | Người đánh giá |
| `product_id` | BIGINT FK → `products.id` | Sản phẩm được đánh giá (để lọc nhanh theo sản phẩm) |
| `order_item_id` | BIGINT FK → `order_items.id`, **UNIQUE** | Dòng hàng đã mua |
| `rating` | TINYINT UNSIGNED | Số sao, `CHECK (rating BETWEEN 1 AND 5)` |
| `title`, `comment` | VARCHAR / TEXT | Tiêu đề, nội dung |
| `status` | ENUM | `pending` (chờ duyệt), `approved` (hiển thị), `hidden` (ẩn) |
| `moderated_by`, `moderated_at` | FK → `users.id` / DATETIME | Nhân viên duyệt (quyền `review.moderate`) |
| `created_at`, `updated_at` | DATETIME | |

- **Liên kết với `order_item_id` thay vì chỉ `product_id`** là chủ ý: `UNIQUE(order_item_id)` bảo đảm mỗi lần mua chỉ đánh giá một lần, và chứng minh người này đã mua.
- Mặc định `pending`, được nhân viên duyệt thì mới hiện và mới tính vào `products.avg_rating`.
- Index `(product_id, status, created_at)`: tải danh sách đánh giá đã duyệt của một sản phẩm.
- Ứng dụng cần đảm bảo `product_id` khớp với sản phẩm của `order_item_id`, và đơn đã ở trạng thái `completed`.

### 9.2. Bảng `articles`: bài viết

**Mục đích:** blog, mẹo sơ chế, công thức nấu lươn (nội dung SEO, guest xem được).

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | BIGINT PK | |
| `author_id` | BIGINT FK → `users.id` | Tác giả (staff/admin) |
| `title` | VARCHAR(250) | Tiêu đề |
| `slug` | VARCHAR(270) UNIQUE | URL thân thiện |
| `summary` | VARCHAR(500) | Tóm tắt |
| `content` | MEDIUMTEXT | Nội dung |
| `thumbnail_url` | VARCHAR(500) | Ảnh đại diện |
| `status` | ENUM | `draft`, `published`, `archived` |
| `published_at` | DATETIME NULL | Ngày xuất bản |
| `view_count` | INT UNSIGNED | Lượt xem |
| `created_at`, `updated_at` | DATETIME | |

Index `(status, published_at)` để lấy bài đã xuất bản mới nhất; `FULLTEXT(title, summary)` để tìm bài viết. Quyền quản lý: `article.manage`.

> **Ghi chú:** các chỉ mục `FULLTEXT` (của `products` và `articles`) chỉ có trong `schema.sql`. File DBML chưa khai báo vì cú pháp DBML không hỗ trợ loại index này (có ghi chú trong phần Note của bảng `products`).

---

## 10. View và Stored Procedure

### 10.1. Ba view

**`v_variant_available_stock`: tồn kho khả dụng theo biến thể**
Chỉ cộng các lô `status = 'available'` và `expiry_date >= CURDATE()`. Loại biến thể combo (tồn của combo tính từ thành phần). Dùng cho trang sản phẩm ("còn hàng / hết hàng") và kiểm tra khi thêm vào giỏ.

| Cột | Ý nghĩa |
|---|---|
| `variant_id`, `sku`, `variant_name`, `variant_type` | Định danh |
| `available_qty` | Tổng số lượng còn bán được |

**`v_batches_expiring_soon`: lô sắp hết hạn (trong 3 ngày)**
Cảnh báo nhân viên kho đẩy hàng, giảm giá hoặc chuẩn bị tiêu hủy.

| Cột | Ý nghĩa |
|---|---|
| `batch_id`, `batch_code`, `sku`, `variant_name` | Định danh lô |
| `expiry_date`, `days_left` | Ngày hết hạn và số ngày còn lại |
| `quantity_remaining` | Còn bao nhiêu |

**`v_daily_revenue`: doanh thu theo ngày (cho admin)**
Chỉ tính đơn `completed`, gom theo ngày `completed_at`.

| Cột | Ý nghĩa |
|---|---|
| `revenue_date` | Ngày |
| `total_orders` | Số đơn hoàn thành |
| `gross_amount` | Tổng tiền hàng (`subtotal`) |
| `total_discount` | Tổng giảm giá (mã + điểm) |
| `total_shipping_fee` | Tổng phí vận chuyển |
| `net_revenue` | Tổng khách đã trả (`total_amount`) |

Quyền xem báo cáo: `report.view_revenue`.

### 10.2. Stored procedure `sp_merge_guest_cart`

**Chữ ký:** `CALL sp_merge_guest_cart(p_guest_token, p_user_id);`

**Các bước (chạy trong một transaction, lỗi thì ROLLBACK):**

1. Tìm giỏ `active` của guest theo `guest_token` và khóa dòng (`FOR UPDATE`).
2. Nếu có giỏ guest: tìm giỏ của user; chưa có thì tạo mới.
3. Chuyển từng dòng từ giỏ guest sang giỏ user bằng `INSERT ... ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`. Dòng trùng biến thể được **cộng dồn**.
4. Xóa các dòng trong giỏ guest.
5. Đánh dấu giỏ guest `status = 'merged'`, ghi `merged_into_cart_id` và `merged_at`.
6. Trả về `merged_into_cart_id`.

Nếu guest token không tồn tại hoặc giỏ đã gộp rồi thì thủ tục không làm gì (idempotent), nên gọi lặp lại không gây cộng dồn hai lần.

---

## 11. Các luồng nghiệp vụ end-to-end

### 11.1. Guest duyệt web, thêm giỏ, rồi đăng nhập

1. Guest xem sản phẩm: truy vấn `products` + `product_variants` (không cần tài khoản).
2. Guest bấm "Thêm vào giỏ": server tạo `guest_token`, `INSERT carts (guest_token, expires_at)`, rồi `INSERT cart_items`. Token gửi về qua cookie HttpOnly.
3. Guest đăng nhập hoặc đăng ký: sau khi xác thực, server gọi `sp_merge_guest_cart(token_từ_cookie, user_id)`.
4. Giỏ hàng chính thức hiển thị gồm cả hàng guest đã thêm.

### 11.2. Đặt hàng (checkout), nên làm trong **một transaction**

1. Đọc giỏ của user, kiểm tra quy tắc `min_order_qty`, `qty_step`, `max_order_qty`.
2. Với mỗi dòng: chọn lô theo FEFO (`SELECT ... FOR UPDATE`). Không đủ tồn thì báo lỗi, ROLLBACK. Với combo thì lặp cho từng thành phần.
3. Tạo `orders` (snapshot địa chỉ, tính tiền, trạng thái `pending`).
4. Tạo `order_items` (snapshot tên, SKU, đơn giá).
5. Trừ kho an toàn: `UPDATE inventory_batches SET quantity_remaining = quantity_remaining - :qty WHERE id = :batch AND quantity_remaining >= :qty`; kiểm tra số dòng bị ảnh hưởng bằng 1.
6. Ghi `order_item_batches` và `inventory_transactions` (`type = 'sale'`, `quantity_change` âm).
7. Ghi `order_status_histories` dòng đầu (`from_status = NULL`, `to_status = pending`).
8. Nếu dùng điểm: ghi `loyalty_transactions` (`redeem`, số âm) và trừ `customer_profiles.loyalty_points`. Nếu dùng mã: tăng `coupons.used_count`.
9. Xóa các dòng trong `cart_items`.
10. COMMIT.

### 11.3. Nhân viên xử lý đơn

```sql
START TRANSACTION;

UPDATE orders
SET status = 'processing', processing_step = 'preparing_eel',
    assigned_staff_id = 2, confirmed_at = NOW()
WHERE id = 3 AND status = 'pending';

INSERT INTO order_status_histories
  (order_id, from_status, to_status, processing_step, changed_by, note)
VALUES (3, 'pending', 'processing', 'preparing_eel', 2, 'Tiếp nhận đơn, bắt đầu sơ chế');

COMMIT;
```

Điều kiện `AND status = 'pending'` ngăn hai nhân viên cùng nhận một đơn; nếu 0 dòng bị cập nhật nghĩa là đã có người nhận.

### 11.4. Hủy đơn

1. Cập nhật `orders`: `status = cancelled`, `processing_step = NULL`, `cancel_reason`, `cancelled_by`, `cancelled_at`.
2. Với mỗi dòng trong `order_item_batches`: cộng lại `quantity_remaining` của lô và ghi `inventory_transactions` (`cancel_restore`, số dương).
3. Hoàn điểm đã dùng (`loyalty_transactions`, `refund`) và giảm `coupons.used_count` nếu cần.
4. Ghi `order_status_histories`.
5. Nếu đã thanh toán trước thì đặt `payment_status = refunded` sau khi hoàn tiền.

### 11.5. Hoàn thành đơn

1. `status = completed`, `completed_at = NOW()`; đơn COD thì `payment_status = paid`, `paid_at`.
2. Cộng điểm: ghi `loyalty_transactions` (`earn`, `points_earned`), cập nhật `customer_profiles.loyalty_points` và `total_spent`; xét lên hạng `loyalty_tier`.
3. Ghi `order_status_histories`.
4. Từ lúc này khách mới được đánh giá các dòng hàng của đơn.

### 11.6. Nhập lô hàng mới (nhân viên kho)

1. Chọn biến thể và nhà cung cấp; ứng dụng gợi ý `expiry_date = received_date + shelf_life_days`.
2. `INSERT inventory_batches` (`quantity_remaining = quantity_received`, `status = available`).
3. `INSERT inventory_transactions` (`type = receive`, `quantity_change` dương, `performed_by` là nhân viên).

### 11.7. Dọn hàng hết hạn (job chạy hằng ngày)

1. Đổi lô đã quá `expiry_date` sang `status = 'expired'`.
2. Nhân viên kho kiểm đếm và tiêu hủy: ghi `inventory_transactions` (`expire_discard`, số âm), đặt `quantity_remaining = 0` và `status = 'discarded'`.
3. Xóa giỏ guest hết hạn: `DELETE FROM carts WHERE user_id IS NULL AND status IN ('active','abandoned') AND expires_at < NOW();`

### 11.8. Admin đổi giá

1. `INSERT price_histories` (giá cũ, giá mới, `changed_by`, lý do).
2. `UPDATE product_variants SET price = ..., sale_price = ...`.
3. Đơn cũ không bị ảnh hưởng nhờ `order_items.unit_price` đã snapshot.

### 11.9. Đánh giá sản phẩm

1. Khách chọn một dòng hàng thuộc đơn `completed` của mình, `INSERT reviews` (`status = pending`).
2. Nhân viên duyệt: `status = approved`, ghi `moderated_by`, `moderated_at`.
3. Cập nhật `products.avg_rating` và `review_count` từ các review `approved`.

---

## 12. Chiến lược index

| Bảng | Index | Truy vấn nó phục vụ |
|---|---|---|
| `products` | FULLTEXT `(name, search_keywords, short_description)` | Ô tìm kiếm sản phẩm |
| `products` | `(category_id, status)` | Trang danh mục, lọc sản phẩm đang bán |
| `products` | `(is_featured, status)` | Sản phẩm nổi bật trang chủ |
| `products`, `categories`, `articles` | UNIQUE `slug` | Tra cứu theo URL |
| `product_variants` | UNIQUE `sku` | Tra cứu theo mã SKU |
| `product_variants` | `(product_id, is_active)` | Các quy cách đang bán của sản phẩm |
| `product_variants` | `(variant_type, is_active)` | Lọc theo loại: sống / sơ chế / đóng hộp |
| `product_variants` | `(price)` | Lọc theo khoảng giá |
| `inventory_batches` | `(variant_id, status, expiry_date)` | **Chọn lô xuất theo FEFO** |
| `inventory_batches` | `(expiry_date, status)` | Quét lô sắp hết hạn |
| `inventory_transactions` | `(batch_id, created_at)` | Lịch sử một lô |
| `carts` | UNIQUE `user_id`, UNIQUE `guest_token` | Tìm giỏ khi mỗi request |
| `carts` | `(status, expires_at)` | Job dọn giỏ guest hết hạn |
| `cart_items` | UNIQUE `(cart_id, variant_id)` | Chống trùng dòng, cộng dồn số lượng |
| `orders` | `(user_id, placed_at)` | Lịch sử đơn của khách |
| `orders` | `(status, placed_at)` | Hàng đợi đơn của nhân viên |
| `orders` | `(assigned_staff_id, status)` | Đơn của từng nhân viên |
| `orders` | `(completed_at)` | Báo cáo doanh thu |
| `order_status_histories` | `(order_id, created_at)` | Timeline đơn |
| `order_status_histories` | `(changed_by, created_at)` | Thống kê năng suất nhân viên |
| `reviews` | `(product_id, status, created_at)` | Danh sách đánh giá một sản phẩm |
| `reviews` | UNIQUE `(order_item_id)` | Chống đánh giá trùng |
| `user_roles` | `(role_id)` | Liệt kê người dùng theo vai trò |

Nguyên tắc: index chứa cột **lọc bằng `=` trước, cột sắp xếp/khoảng sau**, nên một index thường phục vụ cả `WHERE` lẫn `ORDER BY`.

---

## 13. Việc ứng dụng phải tự đảm bảo

Database đã chặn nhiều lỗi bằng khóa, UNIQUE và CHECK, nhưng một số quy tắc nằm ngoài khả năng của schema hiện tại, backend cần tự kiểm tra:

| # | Quy tắc | Vì sao database chưa chặn được |
|---|---|---|
| 1 | Quyền hậu tố `_own`: chỉ thao tác trên dữ liệu của chính mình (`orders.user_id = user hiện tại`) | Database chỉ lưu "có quyền", không biết ngữ cảnh người gọi |
| 2 | Mỗi user chỉ có một `user_addresses.is_default = 1` | MySQL không hỗ trợ unique có điều kiện |
| 3 | Số lượng trong giỏ/đơn khớp `min_order_qty`, `qty_step`, `max_order_qty` | Cần so với bảng khác |
| 4 | Combo (`combo_items`): biến thể combo không được là thành phần của chính nó hay của combo khác | Cần kiểm tra vòng lặp |
| 5 | Chuyển trạng thái đơn đúng thứ tự (không nhảy từ `pending` sang `completed`) | Schema chỉ kiểm tra giá trị hợp lệ, không kiểm tra thứ tự chuyển |
| 6 | Đặt `processing_step = NULL` khi rời trạng thái `processing` | Có CHECK chặn sai, nhưng ứng dụng phải chủ động gán |
| 7 | `quantity_remaining` khớp với tổng `inventory_transactions` | Hai bảng cập nhật riêng, cần cùng một transaction |
| 8 | `orders.total_amount` đúng công thức | Không có CHECK/trigger tính tiền |
| 9 | Chỉ đánh giá đơn đã `completed`; `reviews.product_id` khớp `order_items.variant_id` → sản phẩm | Cần so sánh nhiều bảng |
| 10 | Cộng trừ `customer_profiles.loyalty_points` đi đôi với ghi `loyalty_transactions` | Số dư và sổ cái cập nhật riêng |
| 11 | Cập nhật `avg_rating`, `review_count` khi duyệt/ẩn đánh giá | Cột lưu sẵn, không tự cập nhật |
| 12 | Chuyển `inventory_batches.status` sang `expired` | Cần job định kỳ |
| 13 | Mật khẩu chỉ lưu hash mạnh (bcrypt/argon2); token guest đủ dài, ngẫu nhiên, an toàn mật mã | Ngoài phạm vi schema |

Gợi ý: nếu muốn đẩy bớt trách nhiệm xuống database, các mục 7, 10, 11 có thể chuyển thành trigger hoặc stored procedure; đổi lại logic sẽ nằm ở hai nơi.

---

## 14. Dữ liệu mẫu (seed)

| Bảng | Nội dung mẫu |
|---|---|
| `roles` | 4 vai trò: guest, customer, staff, admin |
| `permissions` | 23 quyền, đã gán sẵn cho từng vai trò |
| `users` | 6 tài khoản: 1 admin (id 1), 2 nhân viên (id 2, 3), 3 khách hàng (id 4, 5, 6) |
| `categories` | 7 danh mục, có cây cha–con (Lươn chế biến sẵn → Đóng hộp, Hút chân không) |
| `products` / `product_variants` | 8 sản phẩm / 10 biến thể: lươn sống theo kg, lươn sơ chế túi 500g và 1kg, lươn um nghệ đóng hộp, lươn chiên giòn hút chân không, gói gia vị, 2 combo |
| `inventory_batches` | 10 lô, trong đó lô id 10 đã **hết hạn** để minh họa hàng cần tiêu hủy |
| `orders` | 4 đơn đủ 4 trạng thái: hoàn thành, đang xử lý (bước đóng gói), chờ xác nhận, đã hủy |
| `inventory_transactions` | Sổ cái khớp từng lô: nhập, bán, hao hụt, hoàn kho do hủy đơn, kiểm kê |
| `coupons` | `WELCOME10` (giảm 10%, tối đa 50.000đ), `FREESHIP30` (giảm 30.000đ) |
| `carts` | 3 giỏ: 1 guest đang hoạt động, 1 giỏ khách hàng, 1 giỏ guest đã gộp |
| `reviews` / `articles` | 2 đánh giá đã duyệt / 3 bài viết đã xuất bản |

**Lưu ý khi dùng seed:**

- `password_hash` là giá trị **giả** (`$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH`). Các tài khoản mẫu chưa đăng nhập được cho đến khi thay bằng hash thật do ứng dụng sinh ra.
- Ngày tháng trong seed nằm quanh 11/2026. Khi chạy ở thời điểm khác, các lô hàng sẽ tự coi là hết hạn do `expiry_date`; chỉnh lại ngày nếu cần xem view tồn kho có dữ liệu.
- Seed chạy lại nhiều lần được vì đầu file có `DROP TABLE IF EXISTS`. **Cảnh báo:** mỗi lần chạy sẽ xóa toàn bộ dữ liệu cũ, đừng chạy trên database đang có dữ liệu thật.

---

*Tài liệu mô tả schema phiên bản MySQL 8.0.16+. Khi chuyển sang PostgreSQL cần đổi ENUM sang `CREATE TYPE`, `AUTO_INCREMENT` sang `IDENTITY`, FULLTEXT sang `tsvector` + GIN, `ON UPDATE CURRENT_TIMESTAMP` sang trigger.*
