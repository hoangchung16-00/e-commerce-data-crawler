# Thiết kế Cơ sở dữ liệu (Database Design)

> **Database**: PostgreSQL (bắt buộc – hỗ trợ JSONB và index tối ưu cao)

---

## 1. ERD Tổng quan

```
users
  │
  └──< campaigns
          │
          └──< products
                  │
                  └──< price_histories
```

---

## 2. Bảng chi tiết

### `users`
Quản lý bởi Devise. Mỗi user sở hữu nhiều campaigns.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | bigint PK | |
| `email` | string | |
| `encrypted_password` | string | |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

---

### `campaigns` (Chiến dịch cào)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | bigint PK | |
| `user_id` | bigint FK | references `users` |
| `name` | string | Tên chiến dịch do user đặt |
| `keyword` | string | Từ khoá tìm kiếm |
| `target_source` | string | `shopee` / `lazada` / `amazon` / `tiki` |
| `frequency` | string | `hourly` / `daily` / `manual` |
| `status` | string | `active` / `paused` / `stopped` |
| `last_crawled_at` | timestamp | Lần crawl cuối |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

**Index:**
```sql
CREATE INDEX idx_campaigns_user_id ON campaigns (user_id);
CREATE INDEX idx_campaigns_status ON campaigns (status);
```

---

### `products` (Sản phẩm gốc)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | bigint PK | |
| `campaign_id` | bigint FK | references `campaigns` |
| `external_id` | string | ID sản phẩm trên trang gốc |
| `name` | string | Tên sản phẩm |
| `url` | text | URL sản phẩm |
| `image_url` | text | URL ảnh đại diện |
| `raw_attributes` | jsonb | Thuộc tính động (màu, size, cấu hình...) |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

**Index:**
```sql
CREATE INDEX idx_products_campaign_id ON products (campaign_id);
CREATE UNIQUE INDEX idx_products_campaign_external ON products (campaign_id, external_id);
-- Full-text search (PgSearch hoặc thủ công)
CREATE INDEX idx_products_name_fts ON products USING GIN (to_tsvector('simple', name));
-- JSONB index nếu cần query theo thuộc tính động
CREATE INDEX idx_products_raw_attributes ON products USING GIN (raw_attributes);
```

---

### `price_histories` (Lịch sử giá – bảng lớn nhất)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | bigint PK | |
| `product_id` | bigint FK | references `products` |
| `price` | decimal(15,2) | Giá tại thời điểm ghi nhận |
| `discount_rate` | decimal(5,2) | % giảm giá (nullable) |
| `recorded_at` | timestamp | Thời điểm cào được giá này |

> ⚠️ **Lưu ý**: Bảng này sẽ tăng trưởng rất nhanh. Xem chiến lược tối ưu ở mục 4.

**Index:**
```sql
-- Composite index – cực kỳ quan trọng cho query biểu đồ theo thời gian
CREATE INDEX idx_price_histories_product_recorded ON price_histories (product_id, recorded_at DESC);
```

---

## 3. Migration mẫu (Rails)

```ruby
# db/migrate/xxx_create_campaigns.rb
create_table :campaigns do |t|
  t.references :user,          null: false, foreign_key: true
  t.string     :name,          null: false
  t.string     :keyword
  t.string     :target_source, null: false
  t.string     :frequency,     default: "daily"
  t.string     :status,        default: "active"
  t.datetime   :last_crawled_at
  t.timestamps
end
add_index :campaigns, :status

# db/migrate/xxx_create_products.rb
create_table :products do |t|
  t.references :campaign,     null: false, foreign_key: true
  t.string     :external_id,  null: false
  t.string     :name,         null: false
  t.text       :url
  t.text       :image_url
  t.jsonb      :raw_attributes, default: {}
  t.timestamps
end
add_index :products, [:campaign_id, :external_id], unique: true
add_index :products, :raw_attributes, using: :gin

# db/migrate/xxx_create_price_histories.rb
create_table :price_histories do |t|
  t.references :product,       null: false, foreign_key: true
  t.decimal    :price,         precision: 15, scale: 2, null: false
  t.decimal    :discount_rate, precision: 5,  scale: 2
  t.datetime   :recorded_at,   null: false
end
add_index :price_histories, [:product_id, :recorded_at]
```

---

## 4. Chiến lược tối ưu bảng `price_histories`

### 4.1 Composite Index
Index `(product_id, recorded_at DESC)` giúp tăng tốc các query phổ biến:
```sql
-- Lấy lịch sử giá của 1 sản phẩm trong 30 ngày
SELECT * FROM price_histories
WHERE product_id = 42
  AND recorded_at >= NOW() - INTERVAL '30 days'
ORDER BY recorded_at DESC;
```

### 4.2 Partial Index (Tối ưu nâng cao)
Nếu chỉ cần query dữ liệu gần đây:
```sql
CREATE INDEX idx_price_histories_recent ON price_histories (product_id, recorded_at DESC)
WHERE recorded_at >= NOW() - INTERVAL '90 days';
```

### 4.3 PostgreSQL Table Partitioning (Phase 3)
Khi bảng đạt hàng triệu bản ghi, partition theo tháng:
```sql
CREATE TABLE price_histories (
  id          BIGSERIAL,
  product_id  BIGINT NOT NULL,
  price       NUMERIC(15,2) NOT NULL,
  recorded_at TIMESTAMP NOT NULL
) PARTITION BY RANGE (recorded_at);

CREATE TABLE price_histories_2024_01
  PARTITION OF price_histories
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Tiếp tục tạo partition cho các tháng tiếp theo...
```

### 4.4 Data Retention Policy
Cân nhắc xoá hoặc archive dữ liệu cũ hơn 2 năm để kiểm soát kích thước bảng.

---

## 5. Query mẫu cho biểu đồ giá (Chartkick + Groupdate)

```ruby
# Trong PriceHistoriesController hoặc Model
@price_data = product.price_histories
  .where(recorded_at: 30.days.ago..)
  .group_by_day(:recorded_at)
  .average(:price)
```

Sinh ra SQL:
```sql
SELECT DATE_TRUNC('day', recorded_at) AS day, AVG(price)
FROM price_histories
WHERE product_id = $1
  AND recorded_at >= $2
GROUP BY 1
ORDER BY 1;
```

---

## 6. Full-text Search với PgSearch

```ruby
# app/models/product.rb
include PgSearch::Model

pg_search_scope :search_by_name,
  against: :name,
  using: {
    tsearch: { prefix: true, dictionary: "simple" }
  }
```

```sql
-- Index hỗ trợ FTS đã tạo ở trên:
CREATE INDEX idx_products_name_fts ON products USING GIN (to_tsvector('simple', name));
```
