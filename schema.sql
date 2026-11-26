-- =====================================================================
-- EEL SHOP DATABASE  |  MySQL 8.0.16+  |  InnoDB, utf8mb4
-- Chay: mysql -u root -p < schema.sql
-- Luu y: password_hash trong seed la gia tri MAU, hay thay bang hash that
--        (bcrypt/argon2) do ung dung tao ra.
-- =====================================================================
CREATE DATABASE IF NOT EXISTS eel_shop
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE eel_shop;
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS v_variant_available_stock, v_batches_expiring_soon, v_daily_revenue;
DROP PROCEDURE IF EXISTS sp_merge_guest_cart;
DROP TABLE IF EXISTS
  articles, reviews, loyalty_transactions, inventory_transactions,
  order_status_histories, order_item_batches, order_items, orders, coupons,
  cart_items, carts, inventory_batches, suppliers, price_histories,
  combo_items, product_variants, product_images, products, categories,
  user_addresses, staff_profiles, customer_profiles, user_roles, users,
  role_permissions, permissions, roles;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 1. AUTH & RBAC
-- =====================================================================
CREATE TABLE roles (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(30)  NOT NULL COMMENT 'guest | customer | staff | admin',
  name        VARCHAR(100) NOT NULL,
  description VARCHAR(255) NULL,
  is_system   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_roles_code (code)
) ENGINE=InnoDB COMMENT='Guest la role logic, khong co ban ghi trong users';

CREATE TABLE permissions (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(80)  NOT NULL COMMENT 'module.action',
  name        VARCHAR(150) NOT NULL,
  module      VARCHAR(40)  NOT NULL,
  description VARCHAR(255) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_permissions_code (code),
  KEY idx_permissions_module (module)
) ENGINE=InnoDB;

CREATE TABLE role_permissions (
  role_id       INT UNSIGNED NOT NULL,
  permission_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE users (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email             VARCHAR(191) NOT NULL,
  phone             VARCHAR(20)  NULL,
  password_hash     VARCHAR(255) NOT NULL,
  full_name         VARCHAR(150) NOT NULL,
  avatar_url        VARCHAR(500) NULL,
  status            ENUM('pending','active','inactive','banned') NOT NULL DEFAULT 'pending',
  email_verified_at DATETIME NULL,
  last_login_at     DATETIME NULL,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at        DATETIME NULL COMMENT 'soft delete',
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email),
  UNIQUE KEY uk_users_phone (phone),
  KEY idx_users_status (status)
) ENGINE=InnoDB;

CREATE TABLE user_roles (
  user_id     BIGINT UNSIGNED NOT NULL,
  role_id     INT UNSIGNED NOT NULL,
  assigned_by BIGINT UNSIGNED NULL,
  assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, role_id),
  KEY idx_user_roles_role (role_id),
  CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles(id),
  CONSTRAINT fk_ur_assigned_by FOREIGN KEY (assigned_by) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE customer_profiles (
  user_id          BIGINT UNSIGNED NOT NULL,
  gender           ENUM('male','female','other') NULL,
  birth_date       DATE NULL,
  loyalty_points   INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'so du diem hien tai',
  loyalty_tier     ENUM('standard','silver','gold','vip') NOT NULL DEFAULT 'standard',
  total_spent      DECIMAL(14,0) NOT NULL DEFAULT 0,
  marketing_opt_in TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_cp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE staff_profiles (
  user_id       BIGINT UNSIGNED NOT NULL,
  employee_code VARCHAR(20) NOT NULL,
  position      VARCHAR(100) NULL,
  hired_at      DATE NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id),
  UNIQUE KEY uk_staff_code (employee_code),
  CONSTRAINT fk_sp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE user_addresses (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id         BIGINT UNSIGNED NOT NULL,
  label           VARCHAR(50) NULL DEFAULT 'Nhà riêng',
  recipient_name  VARCHAR(150) NOT NULL,
  recipient_phone VARCHAR(20)  NOT NULL,
  province        VARCHAR(100) NOT NULL,
  district        VARCHAR(100) NULL COMMENT 'NULL neu dia phuong khong con cap huyen',
  ward            VARCHAR(100) NOT NULL,
  address_line    VARCHAR(255) NOT NULL,
  is_default      TINYINT(1) NOT NULL DEFAULT 0,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_addr_user_default (user_id, is_default),
  CONSTRAINT fk_addr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- 2. CATALOG
-- =====================================================================
CREATE TABLE categories (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  parent_id   INT UNSIGNED NULL,
  name        VARCHAR(150) NOT NULL,
  slug        VARCHAR(180) NOT NULL,
  description VARCHAR(500) NULL,
  image_url   VARCHAR(500) NULL,
  sort_order  INT NOT NULL DEFAULT 0,
  is_active   TINYINT(1) NOT NULL DEFAULT 1,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_categories_slug (slug),
  KEY idx_categories_parent (parent_id, sort_order),
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories(id)
) ENGINE=InnoDB;

CREATE TABLE products (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id       INT UNSIGNED NOT NULL,
  name              VARCHAR(200) NOT NULL,
  slug              VARCHAR(220) NOT NULL,
  short_description VARCHAR(500) NULL,
  description       MEDIUMTEXT NULL,
  thumbnail_url     VARCHAR(500) NULL,
  origin            VARCHAR(150) NULL COMMENT 'vung nuoi / xuat xu',
  search_keywords   VARCHAR(500) NULL COMMENT 'tu khoa KHONG DAU, ung dung tu sinh',
  status            ENUM('draft','active','hidden','discontinued') NOT NULL DEFAULT 'draft',
  is_featured       TINYINT(1) NOT NULL DEFAULT 0,
  avg_rating        DECIMAL(3,2) NOT NULL DEFAULT 0,
  review_count      INT UNSIGNED NOT NULL DEFAULT 0,
  created_by        BIGINT UNSIGNED NULL,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_products_slug (slug),
  KEY idx_products_category_status (category_id, status),
  KEY idx_products_featured (is_featured, status),
  FULLTEXT KEY ft_products_search (name, search_keywords, short_description),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories(id),
  CONSTRAINT fk_products_created_by FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE product_images (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT UNSIGNED NOT NULL,
  url        VARCHAR(500) NOT NULL,
  alt_text   VARCHAR(200) NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_pimg_product (product_id, sort_order),
  CONSTRAINT fk_pimg_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE product_variants (
  id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id           BIGINT UNSIGNED NOT NULL,
  sku                  VARCHAR(50)  NOT NULL,
  name                 VARCHAR(150) NOT NULL,
  variant_type         ENUM('live','fresh_processed','canned','vacuum_pack','combo','condiment') NOT NULL,
  unit                 ENUM('kg','pack','can','combo','piece') NOT NULL,
  weight_grams         INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'khoi luong cho 1 don vi (kg = 1000)',
  price                DECIMAL(12,0) NOT NULL COMMENT 'gia / 1 don vi (VND)',
  sale_price           DECIMAL(12,0) NULL,
  min_order_qty        DECIMAL(10,3) NOT NULL DEFAULT 1.000,
  qty_step             DECIMAL(10,3) NOT NULL DEFAULT 1.000 COMMENT 'luon song: 0.5 kg',
  max_order_qty        DECIMAL(10,3) NULL,
  shelf_life_days      SMALLINT UNSIGNED NULL COMMENT 'goi y expiry_date khi nhap lo',
  requires_cold_chain  TINYINT(1) NOT NULL DEFAULT 0,
  storage_instructions VARCHAR(300) NULL,
  is_active            TINYINT(1) NOT NULL DEFAULT 1,
  sort_order           INT NOT NULL DEFAULT 0,
  created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_variants_sku (sku),
  KEY idx_variants_product (product_id, is_active),
  KEY idx_variants_type (variant_type, is_active),
  KEY idx_variants_price (price),
  CONSTRAINT fk_variants_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT chk_variant_price CHECK (price >= 0),
  CONSTRAINT chk_variant_sale  CHECK (sale_price IS NULL OR sale_price <= price),
  CONSTRAINT chk_variant_qty   CHECK (min_order_qty > 0 AND qty_step > 0)
) ENGINE=InnoDB;

CREATE TABLE combo_items (
  combo_variant_id     BIGINT UNSIGNED NOT NULL,
  component_variant_id BIGINT UNSIGNED NOT NULL,
  quantity             DECIMAL(10,3) NOT NULL,
  PRIMARY KEY (combo_variant_id, component_variant_id),
  KEY idx_combo_component (component_variant_id),
  CONSTRAINT fk_combo_parent FOREIGN KEY (combo_variant_id) REFERENCES product_variants(id),
  CONSTRAINT fk_combo_component FOREIGN KEY (component_variant_id) REFERENCES product_variants(id),
  CONSTRAINT chk_combo_qty CHECK (quantity > 0)
) ENGINE=InnoDB COMMENT='Ton kho combo duoc tru o cac bien the thanh phan; ung dung can dam bao combo <> thanh phan';

CREATE TABLE price_histories (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  variant_id     BIGINT UNSIGNED NOT NULL,
  old_price      DECIMAL(12,0) NOT NULL,
  new_price      DECIMAL(12,0) NOT NULL,
  old_sale_price DECIMAL(12,0) NULL,
  new_sale_price DECIMAL(12,0) NULL,
  changed_by     BIGINT UNSIGNED NOT NULL,
  reason         VARCHAR(255) NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_price_hist (variant_id, created_at),
  CONSTRAINT fk_ph_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id),
  CONSTRAINT fk_ph_user FOREIGN KEY (changed_by) REFERENCES users(id)
) ENGINE=InnoDB;

-- =====================================================================
-- 3. INVENTORY THEO LO
-- =====================================================================
CREATE TABLE suppliers (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name          VARCHAR(200) NOT NULL,
  supplier_type ENUM('farm','processor','condiment_vendor') NOT NULL,
  contact_name  VARCHAR(150) NULL,
  phone         VARCHAR(20)  NULL,
  email         VARCHAR(191) NULL,
  address       VARCHAR(300) NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE inventory_batches (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_code         VARCHAR(50) NOT NULL,
  variant_id         BIGINT UNSIGNED NOT NULL,
  supplier_id        INT UNSIGNED NULL,
  received_by        BIGINT UNSIGNED NULL,
  storage_condition  ENUM('live_tank','chilled','frozen','ambient') NOT NULL,
  produced_date      DATE NULL COMMENT 'ngay san xuat / so che',
  received_date      DATE NOT NULL COMMENT 'ngay nhap',
  expiry_date        DATE NOT NULL COMMENT 'ngay het han / han ban',
  quantity_received  DECIMAL(12,3) NOT NULL,
  quantity_remaining DECIMAL(12,3) NOT NULL,
  unit_cost          DECIMAL(12,0) NOT NULL DEFAULT 0,
  status             ENUM('available','quarantine','expired','depleted','discarded') NOT NULL DEFAULT 'available',
  note               VARCHAR(300) NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_batch_code (batch_code),
  KEY idx_batch_fefo (variant_id, status, expiry_date),
  KEY idx_batch_expiry (expiry_date, status),
  KEY idx_batch_supplier (supplier_id),
  CONSTRAINT fk_batch_variant  FOREIGN KEY (variant_id)  REFERENCES product_variants(id),
  CONSTRAINT fk_batch_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
  CONSTRAINT fk_batch_received_by FOREIGN KEY (received_by) REFERENCES users(id),
  CONSTRAINT chk_batch_qty CHECK (quantity_received >= 0 AND quantity_remaining >= 0
                                  AND quantity_remaining <= quantity_received),
  CONSTRAINT chk_batch_dates CHECK (expiry_date >= received_date)
) ENGINE=InnoDB;

-- =====================================================================
-- 4. GIO HANG (GUEST + CUSTOMER)
-- =====================================================================
CREATE TABLE carts (
  id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id             BIGINT UNSIGNED NULL COMMENT 'NULL neu la gio cua guest',
  guest_token         VARCHAR(64) NULL COMMENT 'cookie HttpOnly cua khach vang lai',
  status              ENUM('active','merged','abandoned') NOT NULL DEFAULT 'active',
  merged_into_cart_id BIGINT UNSIGNED NULL,
  merged_at           DATETIME NULL,
  expires_at          DATETIME NULL COMMENT 'don gio guest het han',
  last_activity_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_carts_user (user_id),
  UNIQUE KEY uk_carts_guest_token (guest_token),
  KEY idx_carts_status_expires (status, expires_at),
  KEY idx_carts_merged_into (merged_into_cart_id),
  CONSTRAINT fk_carts_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_carts_merged_into FOREIGN KEY (merged_into_cart_id) REFERENCES carts(id),
  CONSTRAINT chk_carts_owner CHECK (user_id IS NOT NULL OR guest_token IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE cart_items (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cart_id    BIGINT UNSIGNED NOT NULL,
  variant_id BIGINT UNSIGNED NOT NULL,
  quantity   DECIMAL(10,3) NOT NULL,
  added_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_cart_variant (cart_id, variant_id),
  KEY idx_cart_items_variant (variant_id),
  CONSTRAINT fk_ci_cart FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
  CONSTRAINT fk_ci_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id),
  CONSTRAINT chk_ci_qty CHECK (quantity > 0)
) ENGINE=InnoDB;

-- =====================================================================
-- 5. DON HANG
-- =====================================================================
CREATE TABLE coupons (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  code                VARCHAR(40) NOT NULL,
  description         VARCHAR(255) NULL,
  discount_type       ENUM('percent','fixed') NOT NULL,
  discount_value      DECIMAL(12,2) NOT NULL,
  min_order_amount    DECIMAL(12,0) NOT NULL DEFAULT 0,
  max_discount_amount DECIMAL(12,0) NULL,
  usage_limit         INT UNSIGNED NULL,
  used_count          INT UNSIGNED NOT NULL DEFAULT 0,
  starts_at           DATETIME NULL,
  ends_at             DATETIME NULL,
  is_active           TINYINT(1) NOT NULL DEFAULT 1,
  created_by          BIGINT UNSIGNED NULL,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_coupons_code (code),
  CONSTRAINT fk_coupons_created_by FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE orders (
  id                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_code            VARCHAR(30) NOT NULL,
  user_id               BIGINT UNSIGNED NOT NULL,
  status                ENUM('pending','processing','shipping','completed','cancelled') NOT NULL DEFAULT 'pending'
                        COMMENT 'Cho xac nhan / Dang so che-dong goi / Dang giao / Hoan thanh / Huy',
  processing_step       ENUM('preparing_eel','packing') NULL COMMENT 'chi co gia tri khi status = processing',
  assigned_staff_id     BIGINT UNSIGNED NULL COMMENT 'nhan vien dang phu trach',
  recipient_name        VARCHAR(150) NOT NULL,
  recipient_phone       VARCHAR(20)  NOT NULL,
  shipping_province     VARCHAR(100) NOT NULL,
  shipping_district     VARCHAR(100) NULL,
  shipping_ward         VARCHAR(100) NOT NULL,
  shipping_address_line VARCHAR(255) NOT NULL,
  customer_note         VARCHAR(500) NULL,
  subtotal              DECIMAL(12,0) NOT NULL,
  discount_amount       DECIMAL(12,0) NOT NULL DEFAULT 0,
  points_used           INT UNSIGNED NOT NULL DEFAULT 0,
  points_discount       DECIMAL(12,0) NOT NULL DEFAULT 0,
  shipping_fee          DECIMAL(12,0) NOT NULL DEFAULT 0,
  total_amount          DECIMAL(12,0) NOT NULL,
  points_earned         INT UNSIGNED NOT NULL DEFAULT 0,
  coupon_id             INT UNSIGNED NULL,
  payment_method        ENUM('cod','bank_transfer','momo','vnpay') NOT NULL DEFAULT 'cod',
  payment_status        ENUM('unpaid','paid','refunded') NOT NULL DEFAULT 'unpaid',
  paid_at               DATETIME NULL,
  shipper_name          VARCHAR(150) NULL,
  shipper_phone         VARCHAR(20)  NULL,
  tracking_code         VARCHAR(60)  NULL,
  cancel_reason         VARCHAR(300) NULL,
  cancelled_by          BIGINT UNSIGNED NULL,
  placed_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  confirmed_at          DATETIME NULL,
  shipped_at            DATETIME NULL,
  completed_at          DATETIME NULL,
  cancelled_at          DATETIME NULL,
  updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_orders_code (order_code),
  KEY idx_orders_user (user_id, placed_at),
  KEY idx_orders_status (status, placed_at),
  KEY idx_orders_staff (assigned_staff_id, status),
  KEY idx_orders_payment (payment_status),
  KEY idx_orders_completed (completed_at),
  CONSTRAINT fk_orders_user   FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_orders_staff  FOREIGN KEY (assigned_staff_id) REFERENCES users(id),
  CONSTRAINT fk_orders_coupon FOREIGN KEY (coupon_id) REFERENCES coupons(id),
  CONSTRAINT fk_orders_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES users(id),
  CONSTRAINT chk_orders_step  CHECK (processing_step IS NULL OR status = 'processing'),
  CONSTRAINT chk_orders_total CHECK (subtotal >= 0 AND total_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE order_items (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id     BIGINT UNSIGNED NOT NULL,
  variant_id   BIGINT UNSIGNED NOT NULL,
  product_name VARCHAR(200) NOT NULL COMMENT 'snapshot',
  variant_name VARCHAR(150) NOT NULL COMMENT 'snapshot',
  sku          VARCHAR(50)  NOT NULL COMMENT 'snapshot',
  unit         VARCHAR(10)  NOT NULL,
  quantity     DECIMAL(10,3) NOT NULL,
  unit_price   DECIMAL(12,0) NOT NULL,
  line_total   DECIMAL(12,0) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_oi_order (order_id),
  KEY idx_oi_variant (variant_id),
  CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_oi_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id),
  CONSTRAINT chk_oi_qty CHECK (quantity > 0)
) ENGINE=InnoDB;

CREATE TABLE order_item_batches (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_item_id BIGINT UNSIGNED NOT NULL,
  batch_id      BIGINT UNSIGNED NOT NULL,
  quantity      DECIMAL(12,3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_oib (order_item_id, batch_id),
  KEY idx_oib_batch (batch_id),
  CONSTRAINT fk_oib_item  FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE CASCADE,
  CONSTRAINT fk_oib_batch FOREIGN KEY (batch_id) REFERENCES inventory_batches(id)
) ENGINE=InnoDB COMMENT='Truy xuat nguon goc: don nao da dung lo nao';

CREATE TABLE order_status_histories (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id        BIGINT UNSIGNED NOT NULL,
  from_status     ENUM('pending','processing','shipping','completed','cancelled') NULL,
  to_status       ENUM('pending','processing','shipping','completed','cancelled') NOT NULL,
  processing_step ENUM('preparing_eel','packing') NULL,
  changed_by      BIGINT UNSIGNED NULL COMMENT 'nhan vien / khach / NULL = he thong',
  note            VARCHAR(500) NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_osh_order (order_id, created_at),
  KEY idx_osh_user (changed_by, created_at),
  CONSTRAINT fk_osh_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_osh_user  FOREIGN KEY (changed_by) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE inventory_transactions (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id        BIGINT UNSIGNED NOT NULL,
  type            ENUM('receive','sale','cancel_restore','wastage','adjust','expire_discard') NOT NULL,
  quantity_change DECIMAL(12,3) NOT NULL COMMENT 'co dau: + nhap, - xuat',
  order_id        BIGINT UNSIGNED NULL,
  performed_by    BIGINT UNSIGNED NULL COMMENT 'NULL = he thong',
  note            VARCHAR(300) NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_it_batch (batch_id, created_at),
  KEY idx_it_order (order_id),
  KEY idx_it_type (type, created_at),
  CONSTRAINT fk_it_batch FOREIGN KEY (batch_id) REFERENCES inventory_batches(id),
  CONSTRAINT fk_it_order FOREIGN KEY (order_id) REFERENCES orders(id),
  CONSTRAINT fk_it_user  FOREIGN KEY (performed_by) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE loyalty_transactions (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL,
  order_id      BIGINT UNSIGNED NULL,
  type          ENUM('earn','redeem','adjust','expire','refund') NOT NULL,
  points        INT NOT NULL COMMENT 'co dau: + cong, - tru',
  balance_after INT UNSIGNED NOT NULL,
  note          VARCHAR(255) NULL,
  created_by    BIGINT UNSIGNED NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_lt_user (user_id, created_at),
  CONSTRAINT fk_lt_user  FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_lt_order FOREIGN KEY (order_id) REFERENCES orders(id),
  CONSTRAINT fk_lt_by    FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB;

-- =====================================================================
-- 6. DANH GIA & BAI VIET
-- =====================================================================
CREATE TABLE reviews (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL,
  product_id    BIGINT UNSIGNED NOT NULL,
  order_item_id BIGINT UNSIGNED NOT NULL COMMENT 'moi dong hang chi danh gia 1 lan',
  rating        TINYINT UNSIGNED NOT NULL,
  title         VARCHAR(150) NULL,
  comment       TEXT NULL,
  status        ENUM('pending','approved','hidden') NOT NULL DEFAULT 'pending',
  moderated_by  BIGINT UNSIGNED NULL,
  moderated_at  DATETIME NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_review_order_item (order_item_id),
  KEY idx_review_product (product_id, status, created_at),
  KEY idx_review_user (user_id),
  CONSTRAINT fk_rv_user    FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_rv_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT fk_rv_item    FOREIGN KEY (order_item_id) REFERENCES order_items(id),
  CONSTRAINT fk_rv_mod     FOREIGN KEY (moderated_by) REFERENCES users(id),
  CONSTRAINT chk_rv_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

CREATE TABLE articles (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  author_id     BIGINT UNSIGNED NOT NULL,
  title         VARCHAR(250) NOT NULL,
  slug          VARCHAR(270) NOT NULL,
  summary       VARCHAR(500) NULL,
  content       MEDIUMTEXT NOT NULL,
  thumbnail_url VARCHAR(500) NULL,
  status        ENUM('draft','published','archived') NOT NULL DEFAULT 'draft',
  published_at  DATETIME NULL,
  view_count    INT UNSIGNED NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_articles_slug (slug),
  KEY idx_articles_status (status, published_at),
  FULLTEXT KEY ft_articles_search (title, summary),
  CONSTRAINT fk_articles_author FOREIGN KEY (author_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- =====================================================================
-- VIEWS
-- =====================================================================
-- Ton kho kha dung theo bien the (chi tinh lo con han, tru combo)
CREATE OR REPLACE VIEW v_variant_available_stock AS
SELECT v.id AS variant_id, v.sku, v.name AS variant_name, v.variant_type,
       COALESCE(SUM(CASE WHEN b.status = 'available' AND b.expiry_date >= CURDATE()
                         THEN b.quantity_remaining END), 0) AS available_qty
FROM product_variants v
LEFT JOIN inventory_batches b ON b.variant_id = v.id
WHERE v.variant_type <> 'combo'
GROUP BY v.id, v.sku, v.name, v.variant_type;

-- Lo sap het han trong 3 ngay (canh bao cho nhan vien kho)
CREATE OR REPLACE VIEW v_batches_expiring_soon AS
SELECT b.id AS batch_id, b.batch_code, v.sku, v.name AS variant_name,
       b.expiry_date, DATEDIFF(b.expiry_date, CURDATE()) AS days_left,
       b.quantity_remaining
FROM inventory_batches b
JOIN product_variants v ON v.id = b.variant_id
WHERE b.status = 'available' AND b.quantity_remaining > 0
  AND b.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 3 DAY);

-- Doanh thu theo ngay (cho Admin)
CREATE OR REPLACE VIEW v_daily_revenue AS
SELECT DATE(completed_at) AS revenue_date,
       COUNT(*)            AS total_orders,
       SUM(subtotal)       AS gross_amount,
       SUM(discount_amount + points_discount) AS total_discount,
       SUM(shipping_fee)   AS total_shipping_fee,
       SUM(total_amount)   AS net_revenue
FROM orders
WHERE status = 'completed'
GROUP BY DATE(completed_at);

-- =====================================================================
-- SEED DATA
-- =====================================================================
SET @pw = '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH';

-- ---- Roles & permissions ----
INSERT INTO roles (id, code, name, description) VALUES
(1, 'guest',    'Khách vãng lai', 'Chưa đăng nhập, không có bản ghi trong users. Ứng dụng gán role này khi request không có token.'),
(2, 'customer', 'Khách hàng',     'Tài khoản đã đăng ký'),
(3, 'staff',    'Nhân viên',      'Xử lý đơn hàng, quản lý tồn kho/lô'),
(4, 'admin',    'Quản trị viên',  'Toàn quyền hệ thống');

INSERT INTO permissions (code, name, module) VALUES
('product.view',        'Xem sản phẩm',                         'catalog'),
('article.view',        'Xem bài viết',                         'content'),
('cart.manage_own',     'Quản lý giỏ hàng của mình',            'cart'),
('profile.manage_own',  'Quản lý hồ sơ cá nhân',                'account'),
('address.manage_own',  'Quản lý địa chỉ giao hàng',            'account'),
('order.create',        'Đặt hàng',                             'order'),
('order.view_own',      'Xem lịch sử đơn hàng của mình',        'order'),
('order.cancel_own',    'Hủy đơn khi còn chờ xác nhận',         'order'),
('review.create',       'Đánh giá sản phẩm đã mua',             'review'),
('order.view_all',      'Xem tất cả đơn hàng',                  'order'),
('order.update_status', 'Cập nhật trạng thái đơn hàng',         'order'),
('inventory.view',      'Xem tồn kho và lô hàng',               'inventory'),
('inventory.manage',    'Nhập lô, điều chỉnh tồn kho, hủy hàng hết hạn', 'inventory'),
('review.moderate',     'Duyệt/ẩn đánh giá',                    'review'),
('product.manage',      'Quản lý sản phẩm và biến thể',         'catalog'),
('category.manage',     'Quản lý danh mục',                     'catalog'),
('price.manage',        'Cấu hình giá bán',                     'catalog'),
('article.manage',      'Quản lý bài viết',                     'content'),
('coupon.manage',       'Quản lý mã giảm giá',                  'marketing'),
('report.view_revenue', 'Xem báo cáo doanh thu',                'report'),
('user.manage',         'Quản lý tài khoản khách hàng',         'system'),
('staff.manage',        'Quản lý nhân viên',                    'system'),
('role.manage',         'Quản lý vai trò và phân quyền',        'system');

-- guest
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
  ON p.code IN ('product.view','article.view','cart.manage_own')
WHERE r.code = 'guest';
-- customer
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
  ON p.code IN ('product.view','article.view','cart.manage_own','profile.manage_own',
                'address.manage_own','order.create','order.view_own','order.cancel_own','review.create')
WHERE r.code = 'customer';
-- staff
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
  ON p.code IN ('product.view','article.view','profile.manage_own','order.view_all',
                'order.update_status','inventory.view','inventory.manage','review.moderate')
WHERE r.code = 'staff';
-- admin: toan quyen
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'admin';

-- ---- Users ----
INSERT INTO users (id, email, phone, password_hash, full_name, status, email_verified_at, created_at) VALUES
(1, 'admin@luonviet.vn',       '0900000001', @pw, 'Nguyễn Quốc Bảo', 'active', '2026-01-10 08:00:00', '2026-01-10 08:00:00'),
(2, 'tuan.le@luonviet.vn',     '0900000002', @pw, 'Lê Minh Tuấn',    'active', '2026-02-01 08:00:00', '2026-02-01 08:00:00'),
(3, 'ha.pham@luonviet.vn',     '0900000003', @pw, 'Phạm Thu Hà',     'active', '2026-02-01 08:05:00', '2026-02-01 08:05:00'),
(4, 'lan.nguyen@example.com',  '0900000004', @pw, 'Nguyễn Thị Lan',  'active', '2026-09-05 10:00:00', '2026-09-05 10:00:00'),
(5, 'hung.tran@example.com',   '0900000005', @pw, 'Trần Văn Hùng',   'active', '2026-10-12 19:30:00', '2026-10-12 19:30:00'),
(6, 'mai.vo@example.com',      '0900000006', @pw, 'Võ Ngọc Mai',     'active', '2026-11-01 21:00:00', '2026-11-01 21:00:00');

INSERT INTO user_roles (user_id, role_id, assigned_by) VALUES
(1, 4, NULL), (2, 3, 1), (3, 3, 1), (4, 2, NULL), (5, 2, NULL), (6, 2, NULL);

INSERT INTO staff_profiles (user_id, employee_code, position, hired_at) VALUES
(2, 'EMP001', 'Nhân viên sơ chế và đóng gói', '2026-02-01'),
(3, 'EMP002', 'Nhân viên kho',                '2026-02-01');

INSERT INTO customer_profiles (user_id, gender, birth_date, loyalty_points, loyalty_tier, total_spent) VALUES
(4, 'female', '1992-04-18', 58, 'standard', 580000),
(5, 'male',   '1988-11-02', 0,  'standard', 0),
(6, 'female', '1995-07-23', 0,  'standard', 0);

INSERT INTO user_addresses (id, user_id, label, recipient_name, recipient_phone, province, district, ward, address_line, is_default) VALUES
(1, 4, 'Nhà riêng',   'Nguyễn Thị Lan', '0900000004', 'Thành phố Huế',   NULL, 'Phường Phú Hội',  '25 Nguyễn Huệ',    1),
(2, 5, 'Nhà riêng',   'Trần Văn Hùng',  '0900000005', 'Thành phố Đà Nẵng', NULL, 'Phường Hải Châu', '102 Bạch Đằng',     1),
(3, 6, 'Công ty',     'Võ Ngọc Mai',    '0900000006', 'Thành phố Hà Nội', NULL, 'Phường Cầu Giấy', '18 Trần Thái Tông', 1);

-- ---- Categories ----
INSERT INTO categories (id, parent_id, name, slug, description, sort_order) VALUES
(1, NULL, 'Lươn tươi sống',         'luon-tuoi-song',        'Lươn đồng, lươn nuôi còn sống, bán theo kg', 1),
(2, NULL, 'Lươn sơ chế',            'luon-so-che',           'Lươn đã làm sạch nhớt, sẵn sàng nấu',        2),
(3, NULL, 'Lươn chế biến sẵn',      'luon-che-bien-san',     'Món lươn ăn liền, bảo quản lâu',             3),
(4, 3,    'Lươn đóng hộp',          'luon-dong-hop',         NULL, 1),
(5, 3,    'Lươn hút chân không',    'luon-hut-chan-khong',   NULL, 2),
(6, NULL, 'Combo lươn và gia vị',   'combo-luon-gia-vi',     'Combo tiết kiệm, đủ nguyên liệu nấu món', 4),
(7, NULL, 'Gia vị và phụ liệu',     'gia-vi-phu-lieu',       NULL, 5);

-- ---- Products ----
INSERT INTO products (id, category_id, name, slug, short_description, description, origin, search_keywords, status, is_featured, avg_rating, review_count, created_by) VALUES
(1, 1, 'Lươn đồng sống loại 1 (3-4 con/kg)', 'luon-dong-song-loai-1',
 'Lươn đồng size lớn, thịt chắc, còn sống khỏe, giao trong ngày.',
 'Lươn đồng tuyển chọn size 3-4 con/kg, nuôi bể sạch, phù hợp làm lươn xào lăn, nướng, om chuối đậu.',
 'Phong Điền, Huế', 'luon dong song loai 1 luon tuoi eel live', 'active', 1, 5.00, 1, 1),
(2, 1, 'Lươn đồng sống loại 2 (5-7 con/kg)', 'luon-dong-song-loai-2',
 'Lươn đồng size vừa, giá tiết kiệm, phù hợp nấu cháo, miến.',
 'Lươn đồng size 5-7 con/kg, còn sống khỏe, phù hợp nấu cháo lươn, miến lươn.',
 'Phong Điền, Huế', 'luon dong song loai 2 luon tuoi eel live', 'active', 0, 0, 0, 1),
(3, 2, 'Lươn đồng sơ chế làm sạch', 'luon-dong-so-che-lam-sach',
 'Lươn đã làm sạch nhớt, bỏ ruột, đóng túi, ướp lạnh.',
 'Lươn sơ chế sạch nhớt, bỏ ruột, bảo quản ngăn mát, dùng trong 48 giờ.',
 'Nghệ An', 'luon so che lam sach luon sach nhot eel cleaned', 'active', 1, 0, 0, 1),
(4, 4, 'Lươn um nghệ đóng hộp', 'luon-um-nghe-dong-hop',
 'Lươn um nghệ chuẩn vị xứ Nghệ, mở hộp ăn ngay với cơm nóng.',
 'Lươn đồng om nghệ tươi, đóng hộp tiệt trùng, hạn dùng 6 tháng.',
 'Nghệ An', 'luon um nghe dong hop eel canned an lien', 'active', 1, 4.00, 1, 1),
(5, 5, 'Lươn chiên giòn hút chân không', 'luon-chien-gion-hut-chan-khong',
 'Lươn chiên giòn ướp tiêu muối, hút chân không tiện lợi.',
 'Lươn chiên giòn ướp sẵn, hút chân không, bảo quản ngăn mát 30 ngày.',
 'Nghệ An', 'luon chien gion hut chan khong eel vacuum', 'active', 0, 0, 0, 1),
(6, 7, 'Gia vị nấu miến lươn', 'gia-vi-nau-mien-luon',
 'Gói gia vị pha sẵn cho 1 nồi miến lươn 2-3 người.',
 'Hỗn hợp gia vị hành khô, tiêu, nghệ, bột nêm chuyên dùng cho miến lươn.',
 'Việt Nam', 'gia vi nau mien luon spice', 'active', 0, 0, 0, 1),
(7, 6, 'Combo Miến lươn tại nhà', 'combo-mien-luon-tai-nha',
 '1 túi lươn sơ chế 500g + 2 gói gia vị miến lươn.',
 'Combo tiết kiệm, đủ nguyên liệu nấu nồi miến lươn cho 3-4 người.',
 'Nghệ An', 'combo mien luon tai nha combo luon', 'active', 1, 0, 0, 1),
(8, 6, 'Combo Lươn xào lăn', 'combo-luon-xao-lan',
 '1kg lươn sống loại 1 + 2 gói gia vị.',
 'Combo cho món lươn xào lăn: 1kg lươn sống kèm gia vị.',
 'Phong Điền, Huế', 'combo luon xao lan luon song', 'active', 0, 0, 0, 1);

INSERT INTO product_images (product_id, url, alt_text, sort_order, is_primary) VALUES
(1, '/images/products/luon-song-loai-1-1.jpg', 'Lươn đồng sống loại 1', 1, 1),
(3, '/images/products/luon-so-che-1.jpg',       'Lươn sơ chế làm sạch',  1, 1),
(4, '/images/products/luon-um-nghe-hop-1.jpg',  'Lươn um nghệ đóng hộp', 1, 1);

-- ---- Variants ----
INSERT INTO product_variants
(id, product_id, sku, name, variant_type, unit, weight_grams, price, sale_price,
 min_order_qty, qty_step, shelf_life_days, requires_cold_chain, storage_instructions) VALUES
(1,  1, 'LSD-L1-KG',       'Bán theo kg',           'live',            'kg',    1000, 240000, NULL,   0.500, 0.500, 3,   0, 'Giữ lươn trong thùng có nước, nơi thoáng mát. Nên chế biến trong 24 giờ.'),
(2,  2, 'LSD-L2-KG',       'Bán theo kg',           'live',            'kg',    1000, 190000, NULL,   0.500, 0.500, 3,   0, 'Giữ lươn trong thùng có nước, nơi thoáng mát.'),
(3,  3, 'LSC-SACH-500G',   'Túi 500g',              'fresh_processed', 'pack',  500,  135000, NULL,   1.000, 1.000, 2,   1, 'Bảo quản ngăn mát 0-4°C, dùng trong 48 giờ.'),
(4,  3, 'LSC-SACH-1KG',    'Túi 1kg',               'fresh_processed', 'pack',  1000, 255000, NULL,   1.000, 1.000, 2,   1, 'Bảo quản ngăn mát 0-4°C, dùng trong 48 giờ.'),
(5,  4, 'LUM-HOP-300G',    'Hộp 300g',              'canned',          'can',   300,  95000,  NULL,   1.000, 1.000, 180, 0, 'Nơi khô ráo, tránh ánh nắng. Sau khi mở nên dùng hết trong ngày.'),
(6,  5, 'LCG-VAC-250G',    'Túi hút chân không 250g','vacuum_pack',    'pack',  250,  110000, 99000,  1.000, 1.000, 30,  1, 'Bảo quản ngăn mát, dùng trong 30 ngày.'),
(7,  5, 'LCG-VAC-500G',    'Túi hút chân không 500g','vacuum_pack',    'pack',  500,  205000, NULL,   1.000, 1.000, 30,  1, 'Bảo quản ngăn mát, dùng trong 30 ngày.'),
(8,  6, 'GV-MIENLUON-50G', 'Gói 50g',               'condiment',       'pack',  50,   15000,  NULL,   1.000, 1.000, 365, 0, 'Nơi khô ráo, thoáng mát.'),
(9,  7, 'CB-MIENLUON',     'Combo 1 túi lươn + 2 gói gia vị', 'combo', 'combo', 600,  155000, NULL,   1.000, 1.000, 2,   1, 'Bảo quản ngăn mát, dùng trong 48 giờ.'),
(10, 8, 'CB-LUONXAO',      'Combo 1kg lươn sống + 2 gói gia vị', 'combo', 'combo', 1100, 250000, NULL,  1.000, 1.000, 3,   0, 'Chế biến trong 24 giờ kể từ khi nhận hàng.');

INSERT INTO combo_items (combo_variant_id, component_variant_id, quantity) VALUES
(9, 3, 1.000), (9, 8, 2.000),
(10, 1, 1.000), (10, 8, 2.000);

INSERT INTO price_histories (variant_id, old_price, new_price, old_sale_price, new_sale_price, changed_by, reason, created_at) VALUES
(1, 230000, 240000, NULL, NULL,  1, 'Giá lươn đồng tăng theo thị trường', '2026-11-10 09:00:00'),
(6, 110000, 110000, NULL, 99000, 1, 'Khuyến mãi tháng 11',                '2026-11-12 09:00:00');

-- ---- Suppliers & batches ----
INSERT INTO suppliers (id, name, supplier_type, contact_name, phone, address) VALUES
(1, 'HTX Nuôi trồng thủy sản Phong Điền', 'farm',             'Ông Hoàng Văn Sáu', '0900000101', 'Phong Điền, Thành phố Huế'),
(2, 'Cơ sở chế biến Lươn Vàng',           'processor',        'Bà Trần Thị Nga',   '0900000102', 'Nghệ An'),
(3, 'Công ty Gia vị Việt Hương',          'condiment_vendor', 'Anh Lê Văn Hương',  '0900000103', 'Đà Nẵng');

INSERT INTO inventory_batches
(id, batch_code, variant_id, supplier_id, received_by, storage_condition, produced_date, received_date, expiry_date,
 quantity_received, quantity_remaining, unit_cost, status, note) VALUES
(1,  'LOT-LSD1-20261119-A', 1, 1, 3, 'live_tank', NULL,         '2026-11-19', '2026-11-22', 50.000,  47.500,  170000, 'available', 'Lươn nuôi bể, size 3-4 con/kg'),
(2,  'LOT-LSD1-20261120-A', 1, 1, 3, 'live_tank', NULL,         '2026-11-20', '2026-11-23', 40.000,  40.000,  175000, 'available', NULL),
(3,  'LOT-LSD2-20261119-A', 2, 1, 3, 'live_tank', NULL,         '2026-11-19', '2026-11-22', 60.000,  60.000,  135000, 'available', NULL),
(4,  'LOT-LSC5-20261120-A', 3, 2, 3, 'chilled',   '2026-11-20', '2026-11-20', '2026-11-22', 50.000,  47.000,  95000,  'available', NULL),
(5,  'LOT-LSC1K-20261120-A',4, 2, 3, 'chilled',   '2026-11-20', '2026-11-20', '2026-11-22', 30.000,  30.000,  180000, 'available', NULL),
(6,  'LOT-LUM300-20261001-A',5, 2, 3, 'ambient',  '2026-09-28', '2026-10-01', '2027-04-01', 100.000, 98.000,  62000,  'available', NULL),
(7,  'LOT-LCG250-20261110-A',6, 2, 3, 'chilled',  '2026-11-08', '2026-11-10', '2026-12-10', 80.000,  80.000,  70000,  'available', NULL),
(8,  'LOT-LCG500-20261110-A',7, 2, 3, 'chilled',  '2026-11-08', '2026-11-10', '2026-12-10', 60.000,  60.000,  135000, 'available', NULL),
(9,  'LOT-GVML-20260915-A', 8, 3, 3, 'ambient',   '2026-09-10', '2026-09-15', '2027-09-15', 300.000, 296.000, 8000,   'available', NULL),
(10, 'LOT-LSC5-20261116-A', 3, 2, 3, 'chilled',   '2026-11-16', '2026-11-16', '2026-11-18', 20.000,  6.000,   95000,  'expired',   'Quá hạn - chờ tiêu hủy');

-- ---- Coupons ----
INSERT INTO coupons (id, code, description, discount_type, discount_value, min_order_amount, max_discount_amount, usage_limit, used_count, starts_at, ends_at, created_by) VALUES
(1, 'WELCOME10',  'Giảm 10% đơn đầu tiên, tối đa 50.000đ', 'percent', 10,    200000, 50000, 1000, 1, '2026-11-01 00:00:00', '2026-12-31 23:59:59', 1),
(2, 'FREESHIP30', 'Giảm 30.000đ phí vận chuyển cho đơn từ 500.000đ', 'fixed', 30000, 500000, NULL, NULL, 0, '2026-11-01 00:00:00', '2026-12-31 23:59:59', 1);

-- ---- Orders ----
-- Đơn 1: hoàn thành
INSERT INTO orders (id, order_code, user_id, status, assigned_staff_id, recipient_name, recipient_phone,
  shipping_province, shipping_ward, shipping_address_line, subtotal, shipping_fee, total_amount, points_earned,
  payment_method, payment_status, paid_at, shipper_name, shipper_phone, tracking_code,
  placed_at, confirmed_at, shipped_at, completed_at) VALUES
(1, 'EEL-20261119-0001', 4, 'completed', 2, 'Nguyễn Thị Lan', '0900000004',
  'Thành phố Huế', 'Phường Phú Hội', '25 Nguyễn Huệ', 550000, 30000, 580000, 58,
  'cod', 'paid', '2026-11-19 16:20:00', 'Hoàng Văn Bình', '0900000099', 'HUE-0001',
  '2026-11-19 09:12:00', '2026-11-19 09:30:00', '2026-11-19 11:00:00', '2026-11-19 16:20:00');

-- Đơn 2: đang xử lý (đóng gói), dùng mã giảm giá
INSERT INTO orders (id, order_code, user_id, status, processing_step, assigned_staff_id, recipient_name, recipient_phone,
  shipping_province, shipping_ward, shipping_address_line, customer_note,
  subtotal, discount_amount, shipping_fee, total_amount, coupon_id,
  payment_method, payment_status, paid_at, placed_at, confirmed_at) VALUES
(2, 'EEL-20261120-0001', 5, 'processing', 'packing', 2, 'Trần Văn Hùng', '0900000005',
  'Thành phố Đà Nẵng', 'Phường Hải Châu', '102 Bạch Đằng', 'Giao buổi chiều, gọi trước khi tới',
  300000, 30000, 35000, 305000, 1,
  'bank_transfer', 'paid', '2026-11-20 08:50:00', '2026-11-20 08:40:00', '2026-11-20 08:55:00');

-- Đơn 3: chờ xác nhận
INSERT INTO orders (id, order_code, user_id, status, recipient_name, recipient_phone,
  shipping_province, shipping_ward, shipping_address_line,
  subtotal, shipping_fee, total_amount, payment_method, payment_status, placed_at) VALUES
(3, 'EEL-20261120-0002', 6, 'pending', 'Võ Ngọc Mai', '0900000006',
  'Thành phố Hà Nội', 'Phường Cầu Giấy', '18 Trần Thái Tông',
  155000, 45000, 200000, 'bank_transfer', 'unpaid', '2026-11-20 10:05:00');

-- Đơn 4: đã hủy
INSERT INTO orders (id, order_code, user_id, status, recipient_name, recipient_phone,
  shipping_province, shipping_ward, shipping_address_line,
  subtotal, shipping_fee, total_amount, payment_method, payment_status,
  cancel_reason, cancelled_by, placed_at, cancelled_at) VALUES
(4, 'EEL-20261119-0002', 4, 'cancelled', 'Nguyễn Thị Lan', '0900000004',
  'Thành phố Huế', 'Phường Phú Hội', '25 Nguyễn Huệ',
  380000, 30000, 410000, 'cod', 'unpaid',
  'Khách đổi ý, muốn đặt lại số lượng khác', 4, '2026-11-19 20:15:00', '2026-11-19 20:40:00');

INSERT INTO order_items (id, order_id, variant_id, product_name, variant_name, sku, unit, quantity, unit_price, line_total) VALUES
(1, 1, 1,  'Lươn đồng sống loại 1 (3-4 con/kg)', 'Bán theo kg', 'LSC-PLACEHOLDER', 'kg',    1.500, 240000, 360000),
(2, 1, 5,  'Lươn um nghệ đóng hộp',              'Hộp 300g',    'LUM-HOP-300G',    'can',   2.000, 95000,  190000),
(3, 2, 3,  'Lươn đồng sơ chế làm sạch',          'Túi 500g',    'LSC-SACH-500G',   'pack',  2.000, 135000, 270000),
(4, 2, 8,  'Gia vị nấu miến lươn',               'Gói 50g',     'GV-MIENLUON-50G', 'pack',  2.000, 15000,  30000),
(5, 3, 9,  'Combo Miến lươn tại nhà',            'Combo 1 túi lươn + 2 gói gia vị', 'CB-MIENLUON', 'combo', 1.000, 155000, 155000),
(6, 4, 2,  'Lươn đồng sống loại 2 (5-7 con/kg)', 'Bán theo kg', 'LSD-L2-KG',       'kg',    2.000, 190000, 380000);
-- sua SKU snapshot cua dong 1 cho dung
UPDATE order_items SET sku = 'LSD-L1-KG' WHERE id = 1;

-- Truy xuat lo da dung cho tung dong hang (don 3: combo tru o cac thanh phan)
INSERT INTO order_item_batches (order_item_id, batch_id, quantity) VALUES
(1, 1, 1.500),
(2, 6, 2.000),
(3, 4, 2.000),
(4, 9, 2.000),
(5, 4, 1.000),
(5, 9, 2.000),
(6, 3, 2.000);

INSERT INTO order_status_histories (order_id, from_status, to_status, processing_step, changed_by, note, created_at) VALUES
(1, NULL,         'pending',    NULL,            4,    'Khách đặt hàng',                         '2026-11-19 09:12:00'),
(1, 'pending',    'processing', 'preparing_eel', 2,    'Tiếp nhận đơn, bắt đầu sơ chế lươn',     '2026-11-19 09:30:00'),
(1, 'processing', 'processing', 'packing',       2,    'Sơ chế xong, đang đóng gói',             '2026-11-19 10:30:00'),
(1, 'processing', 'shipping',   NULL,            3,    'Giao cho shipper Hoàng Văn Bình',        '2026-11-19 11:00:00'),
(1, 'shipping',   'completed',  NULL,            3,    'Giao thành công, đã thu COD',            '2026-11-19 16:20:00'),
(2, NULL,         'pending',    NULL,            5,    'Khách đặt hàng',                         '2026-11-20 08:40:00'),
(2, 'pending',    'processing', 'preparing_eel', 2,    'Tiếp nhận đơn',                          '2026-11-20 08:55:00'),
(2, 'processing', 'processing', 'packing',       2,    'Đang đóng gói',                          '2026-11-20 09:40:00'),
(3, NULL,         'pending',    NULL,            6,    'Khách đặt hàng',                         '2026-11-20 10:05:00'),
(4, NULL,         'pending',    NULL,            4,    'Khách đặt hàng',                         '2026-11-19 20:15:00'),
(4, 'pending',    'cancelled',  NULL,            4,    'Khách tự hủy khi chờ xác nhận',          '2026-11-19 20:40:00');

-- ---- Inventory ledger (khop voi quantity_remaining o tren) ----
INSERT INTO inventory_transactions (batch_id, type, quantity_change, order_id, performed_by, note, created_at) VALUES
(1,  'receive',        50.000, NULL, 3, 'Nhập lô lươn sống loại 1',            '2026-11-19 07:30:00'),
(2,  'receive',        40.000, NULL, 3, 'Nhập lô lươn sống loại 1',            '2026-11-20 06:45:00'),
(3,  'receive',        60.000, NULL, 3, 'Nhập lô lươn sống loại 2',            '2026-11-19 07:40:00'),
(4,  'receive',        50.000, NULL, 3, 'Nhập lô lươn sơ chế 500g',            '2026-11-20 06:30:00'),
(5,  'receive',        30.000, NULL, 3, 'Nhập lô lươn sơ chế 1kg',             '2026-11-20 06:35:00'),
(6,  'receive',       100.000, NULL, 3, 'Nhập lô lươn um nghệ đóng hộp',       '2026-10-01 10:00:00'),
(7,  'receive',        80.000, NULL, 3, 'Nhập lô lươn chiên giòn 250g',        '2026-11-10 09:00:00'),
(8,  'receive',        60.000, NULL, 3, 'Nhập lô lươn chiên giòn 500g',        '2026-11-10 09:05:00'),
(9,  'receive',       300.000, NULL, 3, 'Nhập lô gia vị miến lươn',            '2026-09-15 10:00:00'),
(10, 'receive',        20.000, NULL, 3, 'Nhập lô lươn sơ chế 500g',            '2026-11-16 08:00:00'),
(10, 'adjust',        -14.000, NULL, 3, 'Kiểm kê: bán lẻ trực tiếp tại cửa hàng', '2026-11-18 20:00:00'),
(1,  'sale',           -1.500, 1,    NULL, 'Xuất FEFO cho đơn EEL-20261119-0001', '2026-11-19 09:12:00'),
(6,  'sale',           -2.000, 1,    NULL, 'Xuất FEFO cho đơn EEL-20261119-0001', '2026-11-19 09:12:00'),
(1,  'wastage',        -1.000, NULL, 3, 'Lươn chết trong bể (hao hụt)',        '2026-11-19 18:00:00'),
(3,  'sale',           -2.000, 4,    NULL, 'Xuất FEFO cho đơn EEL-20261119-0002', '2026-11-19 20:15:00'),
(3,  'cancel_restore',  2.000, 4,    NULL, 'Hoàn kho do khách hủy đơn',           '2026-11-19 20:40:00'),
(4,  'sale',           -2.000, 2,    NULL, 'Xuất FEFO cho đơn EEL-20261120-0001', '2026-11-20 08:40:00'),
(9,  'sale',           -2.000, 2,    NULL, 'Xuất FEFO cho đơn EEL-20261120-0001', '2026-11-20 08:40:00'),
(4,  'sale',           -1.000, 3,    NULL, 'Combo CB-MIENLUON: trừ thành phần lươn sơ chế', '2026-11-20 10:05:00'),
(9,  'sale',           -2.000, 3,    NULL, 'Combo CB-MIENLUON: trừ thành phần gia vị',      '2026-11-20 10:05:00');

-- ---- Loyalty ----
INSERT INTO loyalty_transactions (user_id, order_id, type, points, balance_after, note, created_at) VALUES
(4, 1, 'earn', 58, 58, 'Tích điểm đơn EEL-20261119-0001 (1 điểm / 10.000đ)', '2026-11-19 16:20:00');

-- ---- Reviews ----
INSERT INTO reviews (user_id, product_id, order_item_id, rating, title, comment, status, moderated_by, moderated_at, created_at) VALUES
(4, 1, 1, 5, 'Lươn rất tươi', 'Lươn còn sống khỏe, size đều, giao nhanh trong buổi sáng.', 'approved', 2, '2026-11-20 08:30:00', '2026-11-20 08:00:00'),
(4, 4, 2, 4, 'Vị vừa miệng', 'Lươn um nghệ thơm, ăn với cơm nóng rất ngon nhưng hộp hơi nhỏ.', 'approved', 3, '2026-11-20 08:35:00', '2026-11-20 08:05:00');

-- ---- Articles ----
INSERT INTO articles (author_id, title, slug, summary, content, status, published_at) VALUES
(1, 'Cách phân biệt lươn đồng và lươn nuôi', 'phan-biet-luon-dong-va-luon-nuoi',
 'Mẹo nhận biết lươn đồng tự nhiên và lươn nuôi khi đi chợ.',
 'Lươn đồng thường có thân nhỏ, màu vàng sẫm, thịt săn chắc. Lươn nuôi to hơn, màu nhạt hơn. Khi chọn lươn sống, hãy ưu tiên con bơi khỏe, da bóng, không trầy xước.',
 'published', '2026-10-20 09:00:00'),
(2, 'Mẹo sơ chế lươn sạch nhớt trong 5 phút', 'meo-so-che-luon-sach-nhot',
 'Cách làm sạch nhớt lươn nhanh, không tanh bằng nguyên liệu có sẵn trong bếp.',
 'Ngâm lươn với nước ấm pha muối và giấm, chà nhẹ với tro bếp hoặc muối hạt rồi rửa lại nhiều lần với nước sạch. Lươn sơ chế xong nên chế biến ngay để giữ độ ngọt của thịt.',
 'published', '2026-10-28 15:00:00'),
(2, 'Công thức miến lươn Nghệ An tại nhà', 'cong-thuc-mien-luon-nghe-an',
 'Hướng dẫn nấu miến lươn đậm vị, nước dùng trong và ngọt.',
 'Lươn luộc chín gỡ lấy thịt, xương ninh lấy nước ngọt. Phi hành khô, xào lươn với nghệ và tiêu, trụng miến rồi chan nước dùng. Ăn kèm rau răm và hành lá.',
 'published', '2026-11-05 10:00:00');

-- ---- Carts: 1 gio guest dang hoat dong, 1 gio khach hang, 1 gio guest da gop ----
INSERT INTO carts (id, user_id, guest_token, status, merged_into_cart_id, merged_at, expires_at) VALUES
(1, NULL, 'gst_7f3a9c2e41b84d5aa1c0e9d2b6f84a31', 'active', NULL, NULL,                  '2026-12-20 00:00:00'),
(2, 6,    NULL,                                   'active', NULL, NULL,                  NULL),
(3, NULL, 'gst_b21e0c9a5d7f4638a9e1c4d7f20b8e65', 'merged', 2,    '2026-11-20 10:00:00', '2026-12-19 00:00:00');

INSERT INTO cart_items (cart_id, variant_id, quantity) VALUES
(1, 1, 0.500),
(1, 8, 1.000),
(2, 6, 1.000),
(2, 1, 0.500);

-- =====================================================================
-- STORED PROCEDURE: GOP GIO HANG GUEST -> GIO CUSTOMER KHI DANG NHAP
-- (Neu chay bang client khong ho tro DELIMITER, hay tao procedure rieng.)
-- =====================================================================
DELIMITER $$

CREATE PROCEDURE sp_merge_guest_cart(IN p_guest_token VARCHAR(64), IN p_user_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_guest_cart_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_user_cart_id  BIGINT UNSIGNED DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT id INTO v_guest_cart_id
  FROM carts
  WHERE guest_token = p_guest_token AND status = 'active'
  FOR UPDATE;

  IF v_guest_cart_id IS NOT NULL THEN
    -- lay hoac tao gio chinh thuc cua user
    SELECT id INTO v_user_cart_id FROM carts WHERE user_id = p_user_id FOR UPDATE;

    IF v_user_cart_id IS NULL THEN
      INSERT INTO carts (user_id, status) VALUES (p_user_id, 'active');
      SET v_user_cart_id = LAST_INSERT_ID();
    END IF;

    -- cong don so luong theo UNIQUE (cart_id, variant_id)
    INSERT INTO cart_items (cart_id, variant_id, quantity)
    SELECT v_user_cart_id, gi.variant_id, gi.quantity
    FROM cart_items gi
    WHERE gi.cart_id = v_guest_cart_id
    ON DUPLICATE KEY UPDATE quantity = cart_items.quantity + VALUES(quantity);

    DELETE FROM cart_items WHERE cart_id = v_guest_cart_id;

    UPDATE carts
    SET status = 'merged', merged_into_cart_id = v_user_cart_id, merged_at = NOW()
    WHERE id = v_guest_cart_id;
  END IF;

  COMMIT;

  SELECT v_user_cart_id AS merged_into_cart_id;
END$$

DELIMITER ;

-- =====================================================================
-- TRUY VAN MAU
-- =====================================================================
-- 1) Gop gio khi guest dang nhap:
--    CALL sp_merge_guest_cart('gst_7f3a9c2e41b84d5aa1c0e9d2b6f84a31', 5);

-- 2) Tim san pham (FULLTEXT, tu khoa khong dau):
--    SELECT p.id, p.name, p.slug, MIN(COALESCE(v.sale_price, v.price)) AS from_price
--    FROM products p
--    JOIN product_variants v ON v.product_id = p.id AND v.is_active = 1
--    WHERE p.status = 'active'
--      AND MATCH(p.name, p.search_keywords, p.short_description)
--          AGAINST('luon song' IN NATURAL LANGUAGE MODE)
--    GROUP BY p.id, p.name, p.slug;

-- 3) Chon lo xuat kho theo FEFO (het han truoc, xuat truoc), khoa dong de tranh ban vuot ton:
--    SELECT id, batch_code, expiry_date, quantity_remaining
--    FROM inventory_batches
--    WHERE variant_id = 1 AND status = 'available'
--      AND expiry_date >= CURDATE() AND quantity_remaining > 0
--    ORDER BY expiry_date ASC, id ASC
--    FOR UPDATE;
--    -- Sau do tru an toan:
--    -- UPDATE inventory_batches SET quantity_remaining = quantity_remaining - :qty
--    -- WHERE id = :batch_id AND quantity_remaining >= :qty;

-- 4) Don dep gio guest het han (chay bang cron/event):
--    DELETE FROM carts
--    WHERE user_id IS NULL AND status IN ('active','abandoned') AND expires_at < NOW();

-- 5) Kiem tra quyen cua 1 user:
--    SELECT DISTINCT p.code
--    FROM user_roles ur
--    JOIN role_permissions rp ON rp.role_id = ur.role_id
--    JOIN permissions p ON p.id = rp.permission_id
--    WHERE ur.user_id = 2;