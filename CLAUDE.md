# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

relaton-w3c is a Ruby gem for retrieving and representing W3C Standards bibliographic data using the Relaton model. It is part of the larger Relaton ecosystem of gems. Uses a LutaML-based model architecture under the `Relaton::W3c` namespace.

## Common Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake spec

# Run a specific test file
bundle exec rspec spec/relaton/w3c/item_spec.rb

# Run a specific test by line number
bundle exec rspec spec/relaton/w3c/item_spec.rb:7

# Lint
bundle exec rubocop

# Interactive console
bin/console
```

## Architecture

### Class Hierarchy

All classes live under `lib/relaton/w3c/` in the `Relaton::W3c` namespace:

**Model classes:**
- **`Item`** (`item.rb`) — extends `Bib::Item`, adds W3C `ext` attribute. Base class for both Bibitem and Bibdata.
- **`ItemData`** (`item_data.rb`) — LutaML data model for `Item`
- **`Bibitem`** (`bibitem.rb`) — extends `Item`, includes `Bib::BibitemShared` (XML serialization without `<bibdata>` wrapper)
- **`Bibdata`** (`bibdata.rb`) — extends `Item`, includes `Bib::BibdataShared` (XML serialization with `<bibdata>` wrapper)
- **`Ext`** (`ext.rb`) — extends `Bib::Ext`, adds W3C-specific `doctype` attribute
- **`Doctype`** (`doctype.rb`) — extends `Bib::Doctype`, restricts content to `groupNote` or `technicalReport`

**Public API:**
- **`Bibliography`** (`bibliography.rb`) — search and retrieve W3C standards from the Relaton index
- **`Processor`** (`processor.rb`) — extends `Relaton::Core::Processor`, registers the W3C flavor (prefix `W3C`, dataset `w3c-api`)

**Data fetching:**
- **`DataFetcher`** (`data_fetcher.rb`) — extends `Core::DataFetcher`, fetches all W3C specs via the W3C API. Fetches the specification index with `embed: true` so each spec is realized from the page's embedded payload instead of a per-spec HTTP request, and paginates by page number (only the `fetch` path repopulates `_embedded`, unlike realizing the `next` link). Runs `fetch_spec` across a small thread pool. A SIGINT (Ctrl-C) is handled gracefully — the producer stops queuing and workers stop after their in-flight spec, then the index of everything fetched so far is saved (the prior INT handler is restored afterwards, so the trap doesn't leak into the host process). If an index page fails to fetch after retries, or pagination ends before the API's advertised last page, `enqueue_specs` raises `CrawlIncompleteError` and the crawl aborts **without** saving the index — a transient rate-limit must never silently truncate the dataset (`crawler.rb` wipes `data/` before each run, so a partial crawl would otherwise commit mass deletions). The worker pool is still drained in an `ensure` so the abort doesn't deadlock. See **Crawler tuning** for the env-var knobs.
- **`DataParser`** (`data_parser.rb`) — converts W3C API spec objects into `Relaton::W3c::Item` instances
- **`SafeRealize`** (`safe_realize.rb`) — mixin that, on a terminal error, skips the resource (returns `nil`) so one bad link doesn't abort the crawl (see Rate limiting & retries). It does not retry or cache successes — those live upstream.
- **`PubId`** (`pubid.rb`) — parses and compares W3C document identifiers (stage, code, date parts)

**Utilities:**
- **`Util`** (`util.rb`) — extends `Relaton::Bib::Util`, sets `PROGNAME` for logging

The entry module is defined in `lib/relaton/w3c.rb` and exposes `grammar_hash`.

### Crawler tuning

`DataFetcher` is tunable via environment variables (read by class methods, so they apply to the whole crawl):

- **`RELATON_W3C_FETCH_CONCURRENCY`** (default `4`) — number of `fetch_spec` worker threads. Kept conservative so the version-history requests don't burst fast enough to trip the W3C API rate limiter (429s); raise it for a faster run, lower it for debugging or if 429 skips appear.
- **`RELATON_W3C_FETCH_VERSIONS`** (default enabled) — set to `false`/`0`/`no`/`off` for a faster, shallower crawl that emits only the top-level specifications and skips each spec's version-history fan-out (version_history, predecessor/successor versions — the bulk of the API requests). Leave it set (the default) for a complete dataset.

`embed: true` (always on) inlines each specification into its index page, so the per-spec realize is served from memory rather than an HTTP request — the largest single reduction in request count.

### Rate limiting & retries

Transient-failure resilience is layered upstream, not in this gem:
- **w3c_api** builds its HAL client with `faraday-retry` to retry HTTP 403 (the W3C rate-limit signal) and connection/timeout errors.
- **lutaml-hal** (beneath w3c_api) retries 429 and 5xx with exponential backoff.

Successful objects are cached by **w3c_api** (lutaml-hal caches realized objects keyed by URL, thread-safely as of lutaml-hal 0.2.1), so `SafeRealize` doesn't cache them. It only **retries nothing** and remembers hrefs that failed terminally (in a `Concurrent::Map`), returning `nil` for them so one bad link doesn't abort the crawl and isn't re-fetched on every reference. Network errors are not remembered, so a later reference can try again.

### Key Dependencies

- **relaton-bib** (~> 2.1.0) — provides base `Bib::Item`, `Bib::Ext`, `Bib::Doctype` and serialization mixins (LutaML model layer)
- **relaton-core** — provides base `Core::Processor` and `Core::DataFetcher`
- **relaton-index** — index-based search for bibliographic references; also unpacks the index zip at runtime
- **w3c_api** (~> 0.3.2) — W3C API (HAL/REST) client used by `DataFetcher` to retrieve specifications; owns rate-limit and transient-error retries, and the (thread-safe) object cache

The W3C data is fetched entirely through `w3c_api`; the older RDF/SPARQL/scraping stack (linkeddata, rdf, sparql, shex, mechanize, …) has been removed.

### Schema Validation

XML output is validated against RelaxNG grammars in `grammars/`:
- `relaton-w3c-compile.rng` — top-level compiled grammar (includes all others)
- `relaton-w3c.rng` — W3C-specific overrides (DocumentType restrictions)
- `basicdoc.rng`, `biblio.rng`, `biblio-standoc.rng` — shared base schemas

Tests use [Jing](https://github.com/jing-trang/jing-trang) for RelaxNG validation.

### Test Structure

Tests use RSpec with:
- **Round-trip tests** — YAML/XML → object → YAML/XML, verifying lossless serialization
- **Schema validation** — XML output validated against `grammars/relaton-w3c-compile.rng`
- **VCR** — recorded HTTP cassettes in `spec/vcr_cassettes/` (7-day re-record interval)
- **WebMock** — disables external HTTP in tests

Test fixtures live in `spec/fixtures/` (YAML and XML files).

## Style

- Follows [Ribose OSS Ruby style guide](https://github.com/riboseinc/oss-guides) via RuboCop
- Target Ruby version: 3.1
- RuboCop config inherits from remote Ribose guide; Rails cops disabled

## CI

GitHub Actions workflows (auto-generated by Cimas) delegate to shared workflows in `relaton/support`:
- `rake.yml` — runs tests on push to main and PRs
- `release.yml` — gem versioning and publishing to RubyGems

## Testing

- **Index fixture:** `spec/fixtures/index-v1.zip` is pre-loaded into `Relaton::Index` pool in `before(:suite)` (configured in `spec/support/webmock.rb`). Run `rake spec:update_index` to refresh from relaton-data-w3c.
