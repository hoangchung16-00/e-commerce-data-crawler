module Scrappers
  # Base scraper error
  class ScraperError < StandardError; end

  # Network-related errors
  class NetworkError < ScraperError; end
  class TimeoutError < NetworkError; end
  class RateLimitError < NetworkError; end
  class ConnectionError < NetworkError; end

  # Parsing-related errors
  class ParsingError < ScraperError; end
  class InvalidHTMLError < ParsingError; end
  class SelectorNotFoundError < ParsingError; end

  # Validation-related errors
  class ValidationError < ScraperError; end
  class MissingFieldError < ValidationError; end
  class InvalidURLError < ValidationError; end
end
