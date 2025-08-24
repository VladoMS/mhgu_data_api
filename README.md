MHGU Monster Data API
======================

Compact, versioned HTTP API that serves cleaned Monster Hunter Generations Ultimate (MHGU) monster data and streamer-friendly star ratings.

This repository contains a small Rack application written in Ruby. The server exposes a searchable monster index, detailed monster data (hitzones, elements, statuses), and simplified "star" views suitable for chat bots and overlays.

Base API prefix: `/api/v1`

Quick start
-----------

Requirements

- Ruby 3.1+
- Bundler

Install dependencies:

```bash
bundle install
```

Run locally with rackup:

```bash
bundle exec rackup -p 4567
```

The API will be reachable at http://localhost:4567. The app loads `./monsters.json` by default; set `MONSTERS_JSON` to override.

Routes
------

All endpoints are versioned under `/api/v1`.

- `GET /api/v1/health` — basic health check.
- `GET /api/v1/legend` — thresholds, icon keys, and notes used by star views.
- `GET /api/v1/monsters` — monster index. Query params: `q` (search), `limit`, `offset`.
- `GET /api/v1/monsters/:slug` — monster detail JSON by slug (case-insensitive, falls back to name match).
- `GET /api/v1/monsters/:slug/views/simple` — merged/simple JSON view across parts.
- `GET /api/v1/monsters/:slug/views/stars` — per-part star ratings and summaries.

Formats & examples
------------------

- Default response: JSON (`Content-Type: application/json`).
- Plain text: append `?format=plain` for Twitch/IRC-friendly text output.

Examples:

```bash
# JSON monster detail
curl -s http://localhost:4567/api/v1/monsters/kelbi

# JSON simple view
curl -s http://localhost:4567/api/v1/monsters/kelbi/views/simple

# Plain text stars (Twitch-friendly)
curl -s "http://localhost:4567/api/v1/monsters/kelbi/views/simple?format=plain"
```

Star thresholds & legend
------------------------

The API exposes `/api/v1/legend` with exact values. Basic rules:

- Hitzones (cut/blunt/shot): ≥45 → 3★, 35–44 → 2★, 25–34 → 1★, <25 → —
- Elements: ≥25 → 3★, 20–24 → 2★, 10–19 → 1★, <10 → —
- Statuses: lower numeric thresholds indicate stronger status (legend shows exact cutoffs).

Development notes
-----------------

- Endpoints are implemented in `api/`:
  - `api/helpers.rb` — shared constants and helpers
  - `api/monsters.rb` — index and search
  - `api/monster.rb` — monster detail and view rendering

- Suggested improvements:
  - Extract pure computation logic into service files for easy unit testing.
  - Add a test suite (Minitest or RSpec) for core services.

Docker
------

Build and run with Docker Compose:

```bash
docker compose up --build
```

Or build and run directly:

```bash
docker build -t mhgu-data-api .
docker run -e MONSTERS_JSON=/data/monsters.json -p 4567:4567 mhgu-data-api
```

Contributing
------------

Open issues or pull requests for bugs and small features. Keep changes focused and include tests where practical.

License
-------

MIT — see the `LICENSE` file.

Short changelog
---------------

- New API is versioned under `/api/v1` and defaults to JSON responses; append `?format=plain` for plain text views.
