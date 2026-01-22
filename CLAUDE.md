# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RelatonW3c is a Ruby gem for retrieving and working with W3C Standards metadata. It implements the IsoBibliographicItem model and is part of the larger Relaton family of bibliographic gems.

## Common Commands

```bash
# Install dependencies
bin/setup

# Run all tests
rake spec

# Run a single test file
bundle exec rspec spec/relaton_w3c/data_fetcher_spec.rb

# Run a specific test (by line number)
bundle exec rspec spec/relaton_w3c/data_fetcher_spec.rb:42

# Interactive console with gem loaded
bin/console

# Lint code (follows Ribose OSS style guide)
bundle exec rubocop

# Build and install gem locally
bundle exec rake install
```

## Architecture

### Core Components

- **W3cBibliography** (`lib/relaton_w3c/w3c_bibliography.rb`): Main entry point for searching and retrieving W3C standards from the relaton-data-w3c repository
- **W3cBibliographicItem** (`lib/relaton_w3c/w3c_bibliographic_item.rb`): Data model representing a W3C bibliographic item
- **DataFetcher** (`lib/relaton_w3c/data_fetcher.rb`): Fetches all W3C documents from the official W3C API (api.w3.org) and saves them locally
- **DataParser** (`lib/relaton_w3c/data_parser.rb`): Parses W3C API specification objects into W3cBibliographicItem instances
- **Processor** (`lib/relaton_w3c/processor.rb`): Relaton processor integration for use with the main relaton gem

### Key Dependencies

- **relaton-bib**: Base bibliographic item model
- **relaton-index**: Index management for document lookups
- **w3c_api**: Ruby client for the W3C API with built-in rate limiting

### Data Flow

1. `DataFetcher.fetch` retrieves specifications from the W3C API using the `w3c_api` gem
2. `DataParser.parse` converts W3C API spec objects to `W3cBibliographicItem`
3. Documents are saved to local files (yaml/xml/bibxml format)
4. `W3cBibliography.get` retrieves cached documents from GitHub relaton-data-w3c repository

### Testing

Uses RSpec with VCR for HTTP request recording. Test cassettes are stored in `spec/vcr_cassettes/`.
