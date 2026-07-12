module Scrappers
  class Factory
    SCRAPERS = {
      "tiki" => "Scrappers::TikiScrapper",
      "amazon" => "Scrappers::AmazonScrapper",
      "shopee" => "Scrappers::ShopeeScrapper",
      "lazada" => "Scrappers::LazadaScrapper"
    }.freeze

    def self.for(target_source)
      scraper_class_name = SCRAPERS[target_source&.downcase]

      raise Scrappers::ScraperError, "Unknown target source: #{target_source}" if scraper_class_name.nil?

      scraper_class_name.constantize
    rescue NameError => e
      raise Scrappers::ScraperError, "Scraper class not found for #{target_source}: #{e.message}"
    end

    def self.register(source_name, scraper_class)
      SCRAPERS[source_name.downcase] = scraper_class
    end

    def self.available_sources
      SCRAPERS.keys
    end
  end
end
