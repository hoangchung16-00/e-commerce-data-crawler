# Lộ trình Phát triển (Development Roadmap)

---

## Phase 1 – MVP (Minimum Viable Product)

**Mục tiêu**: Người dùng nhập một URL sản phẩm, hệ thống cào và hiển thị kết quả ngay.

### Checklist

#### 1.1 Khởi tạo dự án
- [ ] `rails new e-commerce-data-crawler --database=postgresql`
- [ ] Cài đặt và cấu hình Devise (authentication)
- [ ] Tạo migrations cho `users`, `campaigns`, `products`, `price_histories`
- [ ] Seed dữ liệu mẫu

#### 1.2 Web UI cơ bản
- [ ] Layout: Navbar, sidebar
- [ ] Trang tạo Campaign (`campaigns#new` / `campaigns#create`)
- [ ] Trang nhập URL sản phẩm (form đơn giản)
- [ ] Trang danh sách sản phẩm (`products#index`)
- [ ] Trang chi tiết sản phẩm (`products#show`) với bảng lịch sử giá

#### 1.3 Scraper đầu tiên
- [ ] Viết `Scrapers::BaseScraper` (abstract class / module)
- [ ] Viết `Scrapers::TikiScraper` (dùng Nokogiri + Faraday):
  - Lấy: Tên sản phẩm, giá hiện tại, % giảm giá, ảnh
  - Chuẩn hoá output thành Hash
- [ ] Viết `Scrapers::AmazonScraper` tương tự

#### 1.4 Controller trigger scrape
- [ ] Endpoint `POST /products/scrape` nhận URL, gọi Scraper, lưu DB
- [ ] Hiển thị kết quả ngay trên trang (đồng bộ – chưa async)

#### 1.5 Viết tests
- [ ] Unit test cho từng Scraper (dùng VCR/WebMock để mock HTTP)
- [ ] Request spec cho `ProductsController`

---

## Phase 2 – Async & Tự động hoá

**Mục tiêu**: Cào chạy ngầm, lập lịch tự động, giao diện realtime.

### Checklist

#### 2.1 Chuyển Scraper sang Background Job
- [ ] Tạo `CrawlProductJob < ApplicationJob`
  - Nhận `product_id` hoặc `url` và `campaign_id`
  - Gọi đúng Scraper theo `target_source`
  - Lưu `PriceHistory` mới sau mỗi lần cào
- [ ] Controller chỉ enqueue job, không chờ kết quả
  ```ruby
  CrawlProductJob.perform_later(campaign_id: @campaign.id)
  ```
- [ ] Cấu hình **Solid Queue** (hoặc Sidekiq) với ít nhất 2 queue:
  - `default` – các jobs thông thường
  - `crawl` – jobs cào dữ liệu, có thể chạy nhiều worker hơn

#### 2.2 Lập lịch tự động (Recurring Jobs)
- [ ] Tạo `ScheduledCrawlJob` – quét lại tất cả campaigns `active`
- [ ] Cấu hình recurring job chạy lúc **00:00 mỗi ngày**:
  - Solid Queue: cấu hình trong `config/recurring.yml`
  - Sidekiq: dùng `sidekiq-scheduler`
- [ ] Cập nhật `campaign.last_crawled_at` sau mỗi lần chạy

#### 2.3 Realtime với Hotwire + ActionCable
- [ ] Tạo `CrawlProgressChannel`
- [ ] Job broadcast sau khi lưu mỗi sản phẩm:
  ```ruby
  ActionCable.server.broadcast("crawl_progress_#{campaign_id}", {
    product_name: product.name,
    progress: calculate_progress,
    status: "running"
  })
  ```
- [ ] Tạo Turbo Stream template cập nhật:
  - Progress bar (`#crawl-progress`)
  - Danh sách sản phẩm mới (`#products-list`)
- [ ] Stimulus controller xử lý broadcast phía client

#### 2.4 Biểu đồ lịch sử giá
- [ ] Cài đặt `chartkick` + `groupdate`
- [ ] Thêm biểu đồ đường (line chart) vào `products#show`:
  - Trục X: Ngày
  - Trục Y: Giá
  - Hỗ trợ chọn khoảng thời gian: 7 ngày / 30 ngày / 90 ngày
- [ ] JSON endpoint cho biểu đồ: `GET /products/:id/price_chart.json`

#### 2.5 Campaign Management nâng cao
- [ ] Start / Pause / Stop campaign
- [ ] Hiển thị số lượng sản phẩm và lần crawl cuối trên danh sách campaigns
- [ ] Filter campaign theo `target_source`, `status`

---

## Phase 3 – Xử lý nâng cao & Tối ưu *(Điểm CV cao)*

**Mục tiêu**: Hệ thống ổn định, scale được, tìm kiếm mạnh.

### Checklist

#### 3.1 Anti-bot & Rate Limit Handling
- [ ] Xây dựng `UserAgentRotator`:
  - Duy trì danh sách 20+ User-Agent strings thực tế
  - Chọn ngẫu nhiên mỗi request
- [ ] Thêm random delay giữa các request (`sleep(rand(1.0..3.0))`)
- [ ] Cấu hình Proxy list trong `config/crawl_settings.yml`
- [ ] Implement `ProxyRotator` – chọn proxy ngẫu nhiên cho mỗi request Faraday
- [ ] Retry với exponential backoff khi gặp HTTP 429 / 503:
  ```ruby
  retry_on Scrapers::RateLimitError, wait: :exponentially_longer, attempts: 5
  ```

#### 3.2 Xử lý SPA với Ferrum / Cuprite
- [ ] Viết `Scrapers::ShopeeScraper` dùng Ferrum:
  - Khởi động Headless Chrome
  - Chờ selector sản phẩm xuất hiện trước khi parse DOM
  - Đóng browser sau khi xong (tránh memory leak)
- [ ] Viết `Scrapers::LazadaScraper` tương tự
- [ ] Giới hạn concurrency job Ferrum (máy chủ dễ hết RAM)

#### 3.3 Database Optimization
- [ ] Thêm Composite Index `(product_id, recorded_at DESC)` vào `price_histories`
- [ ] Analyze query plan bằng `EXPLAIN ANALYZE` cho các query chậm
- [ ] Implement PostgreSQL **Table Partitioning** cho `price_histories`:
  - Partition theo tháng
  - Viết Rake task tự động tạo partition tháng mới mỗi đầu tháng
- [ ] Cân nhắc Data Retention: Xoá / Archive dữ liệu cũ hơn N năm

#### 3.4 Full-text Search
- [ ] Cài đặt `pg_search`
- [ ] Thêm `pg_search_scope :search_by_name` vào `Product`
- [ ] Thêm GIN index lên `to_tsvector('simple', name)` của `products`
- [ ] Thanh tìm kiếm trên Dashboard với instant search (Turbo Frames)

#### 3.5 Monitoring & Observability
- [ ] Log structured (JSON) cho từng crawl job (thời gian, URL, kết quả)
- [ ] Dashboard admin hiển thị:
  - Số jobs đang pending / running / failed
  - Tỉ lệ thành công / thất bại theo nguồn
- [ ] Alert khi job thất bại liên tục (email hoặc webhook)

#### 3.6 Testing nâng cao
- [ ] Integration test cho toàn bộ luồng crawl (từ Controller → Job → Scraper → DB)
- [ ] VCR cassettes cho HTTP calls thực tế
- [ ] Performance test: Đảm bảo query biểu đồ < 200ms với 1 triệu bản ghi

---

## Sơ đồ Timeline gợi ý

```
Tuần 1-2  │ Phase 1: MVP
           │ ├── Setup, DB migrations
           │ ├── Tiki Scraper + Amazon Scraper
           │ └── Web UI cơ bản
           │
Tuần 3-4  │ Phase 2: Async & Automation
           │ ├── Background Jobs + Solid Queue
           │ ├── Lập lịch tự động
           │ └── Realtime + Biểu đồ giá
           │
Tuần 5-6  │ Phase 3: Advanced
           │ ├── Anti-bot + Proxy
           │ ├── Ferrum scrapers (Shopee, Lazada)
           │ ├── DB Partitioning
           │ └── Full-text Search
```

---

## Tiêu chí hoàn thành

| Phase | Tiêu chí |
|---|---|
| Phase 1 | Nhập URL Tiki → Thấy tên/giá/ảnh hiển thị trên dashboard |
| Phase 2 | Bấm "Start Crawl" → Job chạy ngầm → Dashboard cập nhật realtime → Biểu đồ giá vẽ được |
| Phase 3 | Crawl 100 sản phẩm không bị ban IP, query 1M records < 200ms, tìm kiếm full-text hoạt động |
