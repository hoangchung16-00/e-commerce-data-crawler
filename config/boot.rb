ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Suppress duplicate constant warnings from bundled gems that conflict with Ruby 4.0 built-ins
original_verbose = $VERBOSE
$VERBOSE = nil
require "bundler/setup" # Set up gems listed in the Gemfile.
$VERBOSE = original_verbose

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
