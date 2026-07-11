# E-Commerce Data Crawler

> Hệ thống theo dõi và cào dữ liệu giá sản phẩm từ các sàn thương mại điện tử (Shopee, Lazada, Amazon, Tiki...) được xây dựng trên nền tảng **Ruby on Rails (Monolith)**.

---

## Tính năng chính

- 🔍 **Crawl theo chiến dịch (Campaign)** – Người dùng tạo chiến dịch với từ khóa và nguồn mục tiêu (Shopee / Lazada / Amazon / Tiki).
- 📊 **Biểu đồ lịch sử giá** – Hiển thị biến động giá theo thời gian cho từng sản phẩm.
- ⚙️ **Background Workers** – Tác vụ cào chạy ngầm, không ảnh hưởng đến trải nghiệm Web.
- ⏰ **Tự động lập lịch** – Hệ thống tự quét lại toàn bộ sản phẩm mỗi ngày / mỗi giờ.
- 📡 **Cập nhật realtime** – Dashboard cập nhật tiến độ và dữ liệu mới qua Hotwire / ActionCable.
- 🛡️ **Anti-bot & Rate Limit** – Xoay vòng User-Agent và hỗ trợ Proxy list.
- 🔎 **Full-text Search** – Tìm kiếm sản phẩm nhanh trên Dashboard bằng PostgreSQL FTS / PgSearch.

---

## Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────┐
│              Rails Monolith Application          │
│                                                 │
│  ┌─────────────────┐   ┌──────────────────────┐ │
│  │  Web Dashboard  │   │   Crawl Engine       │ │
│  │  (User Facing)  │   │   (Background Jobs)  │ │
│  │                 │◄──│                      │ │
│  │  Campaigns      │   │  CrawlProductJob     │ │
│  │  Products       │   │  ScheduledCrawlJob   │ │
│  │  Price Charts   │   │  Scrapers::*Scraper  │ │
│  └────────┬────────┘   └──────────┬───────────┘ │
│           │                       │             │
│           └──────────┬────────────┘             │
│                      ▼                          │
│              PostgreSQL Database                │
└─────────────────────────────────────────────────┘
```

Chi tiết xem tại [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Tech Stack

| Layer | Công nghệ |
|---|---|
| Framework | Ruby on Rails 8 |
| Database | PostgreSQL |
| Background Jobs | Solid Queue (hoặc Sidekiq + Redis) |
| HTML Scraping | Nokogiri |
| JS Rendering | Ferrum (Cuprite) / Selenium-webdriver |
| Realtime UI | Hotwire (Turbo Streams + Stimulus) + ActionCable |
| Charts | Chartkick + Groupdate |
| Search | PgSearch |
| Auth | Devise |

Chi tiết xem tại [`docs/TECH_STACK.md`](docs/TECH_STACK.md).

---

## Cấu trúc thư mục dự kiến

```
app/
  controllers/
    campaigns_controller.rb
    products_controller.rb
    price_histories_controller.rb
  jobs/
    crawl_product_job.rb
    scheduled_crawl_job.rb
  services/
    scrapers/
      base_scraper.rb
      tiki_scraper.rb
      amazon_scraper.rb
      shopee_scraper.rb
      lazada_scraper.rb
  models/
    user.rb
    campaign.rb
    product.rb
    price_history.rb
  views/
    campaigns/
    products/
    shared/
      _progress_bar.html.erb
  channels/
    crawl_progress_channel.rb
db/
  migrate/
  schema.rb
docs/
  ARCHITECTURE.md
  DATABASE_DESIGN.md
  TECH_STACK.md
  DEVELOPMENT_ROADMAP.md
```

---

## Lộ trình phát triển

| Pha | Mục tiêu |
|---|---|
| **Phase 1 – MVP** | Cào URL đơn lẻ, lưu DB, hiển thị giao diện |
| **Phase 2 – Async & Automation** | Background jobs, lập lịch tự động |
| **Phase 3 – Advanced** | Anti-bot, DB optimization, Full-text Search |

Chi tiết xem tại [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md).

---

## Cơ sở dữ liệu

Chi tiết thiết kế schema, index và chiến lược tối ưu xem tại [`docs/DATABASE_DESIGN.md`](docs/DATABASE_DESIGN.md).

---

## Khởi động dự án (sau khi init Rails app)

```bash
# Cài đặt dependencies
bundle install

# Tạo và migrate database
rails db:create db:migrate

# Khởi động server
bin/rails server

# Khởi động background worker (Solid Queue)
bin/jobs

# (Tuỳ chọn) Khởi động Sidekiq nếu dùng Redis
bundle exec sidekiq
```

---

## Đóng góp

1. Fork repo
2. Tạo branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m 'feat: add your feature'`
4. Push và mở Pull Request

---

## Giấy phép

MIT License
