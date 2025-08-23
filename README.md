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

### 3. Get monster data

#### Default (raw JSON)
```http
GET /monster?name=Zinogre
```

Clean JSON with A/B tabs, only fields with values > 0.

---

#### Star ratings (Twitch text)

Classic A/B tables:
```http
GET /monster?name=Zinogre&stars=1
```

Collapsed (Wilds-style merged):
```http
GET /monster?name=Zinogre&stars=2
```

---

#### Star ratings (JSON with summaries)

Classic A/B with `best_raw`, `best_elem`, per-part stars:
```http
GET /monster?name=Zinogre&stars=1&format=json
```

Collapsed with `header.best_weapons`, `header.best_elements`, per-part stars:
```http
GET /monster?name=Zinogre&stars=2&format=json
```

**Example (stars=2, format=json):**
```json
{
  "name": "Zinogre",
  "slug": "zinogre",
  "url": "https://mhgu.kiranico.com/monster/...",
  "header": {
    "best_weapons": [
      { "type": "cut", "icon": "⚔️", "part": "Foreleg", "value": 45, "stars": "★★★" },
      { "type": "blunt", "icon": "🔨", "part": "Head", "value": 45, "stars": "★★★" },
      { "type": "shot", "icon": "🎯", "part": "Head", "value": 70, "stars": "★★★" }
    ],
    "best_elements": [
      { "element": "ice", "icon": "❄️", "part": "Hindleg", "value": 25, "stars": "★★★" },
      { "element": "dragon", "icon": "🐉", "part": "Head", "value": 10, "stars": "★" }
    ]
  },
  "parts": [
    {
      "part": "Head",
      "raw": { "cut": 30, "blunt": 45, "shot": 70 },
      "element": { "ice": 25, "dragon": 10 },
      "stars": {
        "cut": "★",
        "blunt": "★★★",
        "shot": "★★★",
        "ice": "★★★",
        "dragon": "★"
      }
    }
  ],
  "status": [
    { "key": "stun", "icon": "💫", "initial": 150, "stars": "★★★" },
    { "key": "poison", "icon": "☠️", "initial": 180, "stars": "★★" }
  ]
}
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
