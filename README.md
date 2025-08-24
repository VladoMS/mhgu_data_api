# MHGU Monster Data API

A small Ruby + Rack API that serves **Monster Hunter Generations Ultimate (MHGU)** monster data scraped from [Kiranico](https://mhgu.kiranico.com/).  
It exposes both **raw JSON data** and **Twitch/overlay-friendly star ratings** for hitzones, elements, and abnormal statuses.

---

## ✨ Features

- Full monster list with names, slugs, and URLs
- Detailed monster data with:
  - **Hitzone values** (cut / blunt / shot)
  - **Elemental weaknesses** (fire / water / thunder / ice / dragon)
  - **Abnormal status thresholds** (poison, paralysis, sleep, stun, exhaust, blast, jump, mount)
- Multiple output formats:
  - **Raw JSON** (cleaned, no zeros or nulls)
  - **Star rating text** (for Twitch chat / bots)
  - **Star rating JSON** (with summaries and per-part)

---

## 📦 Requirements

- Ruby 3.1+ (works fine with rbenv)
- Bundler
- Gems: `rack`, `json`

Install dependencies:

```bash
bundle install
```

---

## 🚀 Running

Start the server with Rack:

```bash
bundle exec rackup -p 4567
```

The API will be available at [http://localhost:4567](http://localhost:4567).

---

## 🔑 Endpoints

### 1. Healthcheck
```http
GET /health
```

### 2. List monsters
```http
GET /monsters
GET /monsters?q=zinogre
```

**Example response:**
```json
{
  "count": 1,
  "total": 1,
  "offset": 0,
  "limit": 9999,
  "items": [
    {
      "name": "Zinogre",
      "slug": "zinogre",
      "url": "https://mhgu.kiranico.com/monster/xxxxx",
      "api_url": "/monster?name=zinogre"
    }
  ]
}
```

# MHGU Monster Data API

A small Ruby + Rack API that serves **Monster Hunter Generations Ultimate (MHGU)** monster data scraped from [Kiranico](https://mhgu.kiranico.com/).
It exposes both **raw JSON data** and **Twitch/overlay-friendly star ratings** for hitzones, elements, and abnormal statuses.

---

## ✨ Features

- Full monster list with names, slugs, and URLs
- Detailed monster data with:
  - **Hitzone values** (cut / blunt / shot)
  - **Elemental weaknesses** (fire / water / thunder / ice / dragon)
  - **Abnormal status thresholds** (poison, paralysis, sleep, stun, exhaust, blast, jump, mount)
- Multiple output formats:
  - **Raw JSON** (cleaned, no zeros or nulls)
  - **Star rating text** (for Twitch chat / bots)
  - **Star rating JSON** (with summaries and per-part stars)

---

## 📦 Requirements

- Ruby 3.1+ (works fine with rbenv)
- Bundler
- Gems: `rack`, `json`

Install dependencies:

```bash
bundle install
```

---

## 🚀 Running

Start the server with Rack:

```bash
bundle exec rackup -p 4567
```

The API will be available at [http://localhost:4567](http://localhost:4567).

---

## 🔑 Endpoints (legacy docs)

These are the original (pre-versioned) endpoints; the new routes are documented in the "Routes (new)" section below.

### 1. Healthcheck
```http
GET /health
```

### 2. List monsters
```http
GET /monsters
GET /monsters?q=zinogre
```

**Example response:**
```json
{
  "count": 1,
  "total": 1,
  "offset": 0,
  "limit": 9999,
  "items": [
    {
      "name": "Zinogre",
      "slug": "zinogre",
      "url": "https://mhgu.kiranico.com/monster/xxxxx",
      "api_url": "/monster?name=zinogre"
    }
  ]
}
```

### Routes

Quick reference for the new RESTful routes (versioned).

Base prefix: `/api/v1`

Endpoints

- Health
  - GET /api/v1/health
  - Returns 200 and a small JSON health object.

- Legend / metadata
  - GET /api/v1/legend
  - Returns threshold values, icons and notes as JSON.

- Monsters collection (list / search)
  - GET /api/v1/monsters
  - Query params: `q`, `limit`, `offset`
  - Example: `/api/v1/monsters?q=zinogre&limit=10`

- Monster resource (by slug)
  - GET /api/v1/monsters/:slug
  - Returns cleaned JSON by default (A/B tabs, status, hitzones).
  - Example: `/api/v1/monsters/kelbi`

- Monster views
  - GET /api/v1/monsters/:slug/views/simple
    - Replaces previous "collapsed" view; returns merged/simple view
    - JSON default, `?format=plain` for plain text
    - Example: `/api/v1/monsters/kelbi/views/simple`

Format rules
- Default output is JSON (Content-Type: application/json).
- To request plain text (Twitch-friendly), append `?format=plain`.

Slug note
- The `:slug` path segment should be the monster slug (lowercase, hyphenated). The server attempts a case-insensitive lookup and will match by name if necessary.

Examples (curl)
```bash
# JSON default
curl -s http://localhost:4567/api/v1/monsters/kelbi

# plain text stars view
curl -s http://localhost:4567/api/v1/monsters/kelbi/views/stars?format=plain

# JSON simple (merged) view
curl -s http://localhost:4567/api/v1/monsters/kelbi/views/simple
```

---

## ⚔️ Star rating thresholds

**Raw hitzones (cut/blunt/shot):**
- `≥ 45` → ★★★
- `35–44` → ★★
- `25–34` → ★
- `< 25` → —

**Elements (fire/water/thunder/ice/dragon):**
- `≥ 25` → ★★★
- `20–24` → ★★
- `10–19` → ★
- `< 10` → —

**Statuses (poison, stun, etc.):**
- `≤ 150` → ★★★ (very weak to it)
- `151–300` → ★★
- `301–500` → ★
- `> 500` → —

---

## 🎯 Usage Ideas

- Hook into **Streamer.bot** or any Twitch bot to reply with monster weaknesses:
  ```
  !mhgu zinogre
  !mhgu zinogre stars=2
  ```
- Display JSON data in overlays (OBS / web overlays).
- Generate cards or infographics.

---

## 📝 License

MIT — free to use, modify, and share.

---

