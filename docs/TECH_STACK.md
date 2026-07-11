# Tech Stack & Gem Chiến lược

## 1. Nền tảng

| Công nghệ | Phiên bản khuyến nghị | Lý do chọn |
|---|---|---|
| **Ruby** | 3.3+ | Hiệu năng tốt, cú pháp rõ ràng |
| **Ruby on Rails** | 8.0+ | Monolith, Solid Queue mặc định, Hotwire tích hợp sẵn |
| **PostgreSQL** | 15+ | JSONB, Full-text Search, Table Partitioning, Index mạnh |

---

## 2. Scraping – Cào dữ liệu

### Nokogiri
- **Dùng khi**: Trang web render HTML phía server (Server-Side Rendered) – ví dụ Tiki, Amazon (một số trang).
- **Ưu điểm**: Cực nhanh, ít tài nguyên, viết bằng C.
- **Ví dụ sử dụng**:
  ```ruby
  doc = Nokogiri::HTML(response.body)
  name  = doc.css("h1.product-name").text.strip
  price = doc.css("span.price").text.gsub(/\D/, "").to_i
  ```

### Ferrum / Cuprite
- **Dùng khi**: Trang Single Page Application (SPA) load dữ liệu bằng JavaScript sau khi tải trang – ví dụ Shopee, Lazada.
- **Ưu điểm**: Điều khiển Headless Chrome thực sự, hỗ trợ chờ AJAX xong mới lấy DOM.
- **Lưu ý**: Tốn RAM hơn Nokogiri, nên giới hạn concurrency của job loại này.
- **Gem**: `cuprite` (wrapper Ferrum dành cho Capybara / standalone)

### Selenium-webdriver (thay thế Ferrum)
- Dùng khi cần tương thích rộng hơn hoặc đã quen với Selenium API.

---

## 3. Background Jobs – Hàng đợi chạy ngầm

### Solid Queue *(khuyến nghị mặc định – Rails 8)*
- Không cần Redis, lưu jobs trong PostgreSQL.
- Tích hợp sẵn với Rails 8, cấu hình qua `config/queue.yml`.
- Hỗ trợ concurrency workers, recurring jobs (thay thế cron).

### Sidekiq *(nếu cần hiệu năng cao hơn)*
- Yêu cầu Redis.
- Xử lý hàng triệu jobs/phút, phù hợp khi scale lớn.
- Có Web UI tích hợp để monitor jobs.
- **Gem**: `sidekiq`, `sidekiq-scheduler` (cho recurring jobs)

---

## 4. Giao diện & Realtime

### Hotwire (Turbo + Stimulus)
- Tích hợp sẵn trong Rails 8.
- **Turbo Streams**: Cập nhật DOM partial mà không reload trang.
- **Stimulus**: Xử lý JS nhỏ phía client khi cần.

### ActionCable
- WebSocket tích hợp trong Rails.
- Crawl Engine broadcast tiến độ qua `CrawlProgressChannel`.
- Dashboard lắng nghe và cập nhật Progress bar + danh sách sản phẩm realtime.

---

## 5. Biểu đồ – Charts

### Chartkick
- Vẽ biểu đồ đẹp chỉ với 1 dòng Ruby trong view.
- **Gem**: `chartkick`

### Groupdate
- Nhóm dữ liệu theo ngày / tuần / tháng cực dễ dàng với ActiveRecord.
- **Gem**: `groupdate`

**Ví dụ kết hợp:**
```erb
<%= line_chart product.price_histories
                       .where(recorded_at: 30.days.ago..)
                       .group_by_day(:recorded_at)
                       .average(:price) %>
```

---

## 6. Authentication

### Devise
- Giải pháp xác thực chuẩn trong Rails, đầy đủ tính năng.
- **Gem**: `devise`

---

## 7. Full-text Search

### PgSearch
- Tận dụng sức mạnh Full-text Search của PostgreSQL ngay trong Rails.
- Không cần Elasticsearch, không cần infrastructure thêm.
- **Gem**: `pg_search`

---

## 8. HTTP Client (cho Scraping tĩnh)

### Faraday hoặc HTTParty
- Gửi HTTP request với hỗ trợ middleware, retry, timeout.
- **Gem**: `faraday` hoặc `httparty`

### Faraday-retry
- Tự động retry khi gặp lỗi mạng hoặc rate limit (HTTP 429, 503).
- **Gem**: `faraday-retry`

---

## 9. Tóm tắt Gemfile dự kiến

```ruby
# Gemfile

# Core
gem "rails", "~> 8.0"
gem "pg"
gem "puma"

# Auth
gem "devise"

# Scraping
gem "nokogiri"
gem "cuprite"           # Headless Chrome (Ferrum-based)
gem "faraday"
gem "faraday-retry"

# Background Jobs
gem "solid_queue"       # Default Rails 8 (hoặc thay bằng sidekiq)
# gem "sidekiq"
# gem "sidekiq-scheduler"

# Realtime & Frontend
# Hotwire tích hợp sẵn Rails 8

# Charts
gem "chartkick"
gem "groupdate"

# Search
gem "pg_search"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "web-console"
  gem "better_errors"
end
```

---

## 10. Cân nhắc khi chọn Scraping Strategy

| Trang | Loại | Scraper nên dùng |
|---|---|---|
| Tiki | SSR (Server-Side Rendered) | Nokogiri + Faraday |
| Amazon | SSR (phần lớn) | Nokogiri + Faraday |
| Shopee | SPA (JavaScript) | Ferrum / Cuprite |
| Lazada | SPA (JavaScript) | Ferrum / Cuprite |

> **Gợi ý**: Bắt đầu với Nokogiri cho Tiki/Amazon (Phase 1 MVP), sau đó bổ sung Ferrum cho Shopee/Lazada (Phase 2+).
