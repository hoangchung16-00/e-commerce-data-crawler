# Kiến trúc hệ thống (System Architecture)

## 1. Tổng quan

Hệ thống được xây dựng theo mô hình **Rails Monolith**, chia thành hai phần logic rõ rệt nhưng nằm chung một codebase:

```
┌──────────────────────────────────────────────────────────────────┐
│                     Rails Monolith Application                   │
│                                                                  │
│  ┌──────────────────────────┐   ┌──────────────────────────────┐ │
│  │     Web Dashboard        │   │       Crawl Engine           │ │
│  │     (User Facing)        │   │    (Background Workers)      │ │
│  │                          │   │                              │ │
│  │  - Campaigns CRUD        │   │  - CrawlProductJob           │ │
│  │  - Products list/show    │   │  - ScheduledCrawlJob         │ │
│  │  - Price history charts  │   │  - Scrapers::BaseScraper     │ │
│  │  - Filter & Search       │◄──│  - Scrapers::TikiScraper     │ │
│  │  - Realtime progress bar │   │  - Scrapers::AmazonScraper   │ │
│  │                          │   │  - Scrapers::ShopeeScraper   │ │
│  └────────────┬─────────────┘   └──────────────┬───────────────┘ │
│               │   ActionCable (Turbo Streams)   │                 │
│               └──────────────┬─────────────────┘                 │
│                              ▼                                   │
│                    PostgreSQL Database                           │
│            (campaigns, products, price_histories)               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. Web Dashboard (User Facing)

### Trách nhiệm
- Cung cấp giao diện cho người dùng quản lý **Chiến dịch (Campaigns)**.
- Hiển thị danh sách **Sản phẩm (Products)** đã cào được.
- Hiển thị **biểu đồ lịch sử giá** (Chartkick + Groupdate).
- Nhận lệnh từ người dùng (bấm "Start Crawl") và đẩy tác vụ vào hàng đợi.
- Nhận cập nhật **realtime** từ Crawl Engine qua ActionCable / Turbo Streams.

### Controllers chính
| Controller | Chức năng |
|---|---|
| `CampaignsController` | CRUD chiến dịch, kích hoạt / dừng crawl |
| `ProductsController` | Xem danh sách và chi tiết sản phẩm |
| `PriceHistoriesController` | Trả về dữ liệu JSON cho biểu đồ giá |

### Luồng dữ liệu (Request Flow)
```
Browser
  │  POST /campaigns/:id/start_crawl
  ▼
CampaignsController#start_crawl
  │  CrawlProductJob.perform_later(campaign_id)
  ▼
Job Queue (Solid Queue / Sidekiq)
  │  [Chạy ngầm]
  ▼
Scrapers::*Scraper.call(url)
  │  Lưu Product + PriceHistory vào DB
  ▼
ActionCable broadcast → Turbo Stream
  │  Cập nhật DOM không reload trang
  ▼
Browser (realtime update)
```

---

## 3. Crawl Engine (Background Workers)

### Trách nhiệm
- Nhận tác vụ từ hàng đợi và thực hiện cào dữ liệu.
- Parse HTML bằng **Nokogiri** (static pages) hoặc **Ferrum/Cuprite** (SPA / JS-rendered).
- Lưu dữ liệu sản phẩm và lịch sử giá vào DB.
- Phát broadcast qua ActionCable khi hoàn thành mỗi sản phẩm.

### Jobs
| Job | Mô tả |
|---|---|
| `CrawlProductJob` | Cào một sản phẩm cụ thể theo URL |
| `ScheduledCrawlJob` | Được kích hoạt theo lịch (cron), quét lại toàn bộ sản phẩm active |

### Scrapers (Service Objects)
```
app/services/scrapers/
  base_scraper.rb        # Interface chung: #call, #fetch_html, #parse
  tiki_scraper.rb        # Kế thừa BaseScraper, parse đặc thù của Tiki
  amazon_scraper.rb      # Parse Amazon
  shopee_scraper.rb      # Dùng Ferrum vì Shopee là SPA
  lazada_scraper.rb      # Dùng Ferrum vì Lazada là SPA
```

Mỗi Scraper trả về một Hash chuẩn hoá:
```ruby
{
  name:          "Tên sản phẩm",
  price:         199_000,
  discount_rate: 15,
  image_url:     "https://...",
  external_id:   "abc123",
  raw_attributes: { color: "Đen", storage: "128GB" }  # JSONB
}
```

---

## 4. Realtime với Hotwire + ActionCable

```
CrawlProductJob (Worker)
  │  Sau khi lưu DB thành công
  ▼
ActionCable.server.broadcast("crawl_progress_#{campaign_id}", {
  product_name: ...,
  progress: 45,   # %
  status: "running"
})
  │
  ▼
CrawlProgressChannel (app/channels/)
  │  Turbo::StreamsChannel
  ▼
Turbo Stream → Cập nhật #progress-bar và #products-list trên Dashboard
```

---

## 5. Chiến lược Anti-bot

- **User-Agent rotation**: Luân phiên danh sách User-Agent trong mỗi HTTP request.
- **Request delay**: Thêm `sleep(rand(1..3))` giữa các request để tránh bị rate limit.
- **Proxy support**: Cấu hình danh sách Proxy trong `config/crawl_settings.yml`, workers chọn ngẫu nhiên mỗi request.
- **Retry logic**: ActiveJob retry với exponential backoff khi gặp lỗi 429 / 503.

---

## 6. Sơ đồ thành phần (Component Diagram)

```
┌────────┐    HTTP     ┌──────────────┐    Enqueue    ┌─────────────────┐
│ Browser│────────────►│ Rails Router │──────────────►│  Job Queue      │
└────────┘             │ Controllers  │               │  (Solid Queue / │
    ▲                  └──────────────┘               │   Sidekiq)      │
    │                         │                       └────────┬────────┘
    │  WebSocket              │ ActiveRecord                   │ perform
    │  (ActionCable)          ▼                                ▼
    │                  ┌──────────────┐               ┌─────────────────┐
    └──────────────────│  PostgreSQL  │◄──────────────│  Scrapers       │
                       │  Database   │               │  (Nokogiri /    │
                       └──────────────┘               │   Ferrum)       │
                                                      └─────────────────┘
```
