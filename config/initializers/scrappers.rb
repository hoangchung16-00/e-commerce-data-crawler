# Autoload scraper classes
require Rails.root.join("lib/scrappers/errors")
require Rails.root.join("lib/scrappers/http_client")
require Rails.root.join("lib/scrappers/base_scrapper")
require Rails.root.join("lib/scrappers/factory")
require Rails.root.join("lib/scrappers/tiki_scrapper")

# Concrete scrapers will be required when needed or can be loaded here after implementation
# require Rails.root.join('lib/scrappers/amazon_scrapper')
