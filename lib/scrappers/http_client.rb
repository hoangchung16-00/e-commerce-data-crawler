require "faraday"
require "faraday/retry"

module Scrappers
  class HttpClient
    USER_AGENTS = [
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
    ].freeze

    DEFAULT_TIMEOUT = 10
    DEFAULT_RETRIES = 3
    DEFAULT_RETRY_WAIT = 1

    def self.get(url, options = {})
      new(options).get(url)
    end

    def self.post(url, body = {}, options = {})
      new(options).post(url, body)
    end

    def initialize(timeout: DEFAULT_TIMEOUT, retries: DEFAULT_RETRIES, retry_wait: DEFAULT_RETRY_WAIT)
      @timeout = timeout
      @retries = retries
      @retry_wait = retry_wait
      @client = build_client
    end

    def get(url)
      validate_url!(url)
      handle_request(url) { client.get(url) }
    end

    def post(url, body = {})
      validate_url!(url)
      handle_request(url) do
        client.post(url) do |req|
          req.body = body
        end
      end
    end

    private

    attr_reader :client

    def handle_request(url)
      add_polite_delay
      yield
    rescue Faraday::TimeoutError => e
      raise Scrappers::TimeoutError, "Request timeout after #{@timeout}s for URL: #{url}"
    rescue Faraday::TooManyRequestsError => e
      raise Scrappers::RateLimitError, "Rate limited (429) for URL: #{url}"
    rescue Faraday::ConnectionFailed => e
      raise Scrappers::ConnectionError, "Connection failed for URL: #{url} - #{e.message}"
    rescue Faraday::ClientError => e
      raise Scrappers::NetworkError, "HTTP error for URL: #{url} - #{e.message}"
    end

    def build_client
      Faraday.new do |faraday|
        # Add retry middleware with exponential backoff
        faraday.request :retry, {
          max: @retries,
          interval: @retry_wait,
          interval_randomness: 0.5,
          backoff_factor: 2,
          exceptions: [ Errno::ETIMEDOUT, Faraday::TimeoutError, Faraday::ConnectionFailed ]
        }

        faraday.request :url_encoded
        faraday.adapter :net_http
        faraday.options.timeout = @timeout
        faraday.options.open_timeout = @timeout

        # Set random User-Agent to avoid being blocked
        faraday.headers["User-Agent"] = random_user_agent
        faraday.headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        faraday.headers["Accept-Language"] = "en-US,en;q=0.5"
        faraday.headers["Accept-Encoding"] = "gzip, deflate"
        faraday.headers["Connection"] = "keep-alive"
        faraday.headers["DNT"] = "1"
      end
    end

    def random_user_agent
      USER_AGENTS.sample
    end

    def add_polite_delay
      # Add random delay to be respectful to servers
      sleep(rand(1.0..2.5))
    end

    def validate_url!(url)
      raise Scrappers::InvalidURLError, "URL cannot be blank" if url.blank?

      uri = begin
        URI.parse(url)
      rescue URI::InvalidURIError
        raise Scrappers::InvalidURLError, "Invalid URL format: #{url}"
      end

      unless %w[http https].include?(uri.scheme)
        raise Scrappers::InvalidURLError, "URL must use HTTP or HTTPS protocol: #{url}"
      end
    end
  end
end
