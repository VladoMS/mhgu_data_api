# frozen_string_literal: true
require "json"
require "rack"

module MHGU
  RAW_THRESH = { one: 25, two: 35, three: 45 }
  ELM_THRESH = { one: 10, two: 20, three: 25 }
  STATUS_THRESH = { one: 300, two: 150, three: 0 } # lower = easier => more stars

  WEAPON_KEYS = %w[cut blunt shot].freeze
  ELEM_KEYS   = %w[fire water thunder ice dragon].freeze

  WEAPON_ICONS = { "cut"=>"⚔️", "blunt"=>"🔨", "shot"=>"🎯" }.freeze
  ELEM_ICONS   = { "fire"=>"🔥", "water"=>"💧", "thunder"=>"⚡", "ice"=>"❄️", "dragon"=>"🐉" }.freeze
  STATUS_ICONS = {
    "poison"=>"☠️", "paralysis"=>"⚡", "sleep"=>"😴", "stun"=>"💫",
    "exhaust"=>"🌀", "blast"=>"💥", "jump"=>"🦘", "mount"=>"🧗"
  }.freeze

  def self.stars_for(value, thresholds)
    return "—" unless value.is_a?(Numeric)
    case thresholds
    when RAW_THRESH, ELM_THRESH
      case value
      when thresholds[:three]..                  then "★★★"
      when thresholds[:two]...thresholds[:three] then "★★"
      when thresholds[:one]...thresholds[:two]   then "★"
      else "—"
      end
    when STATUS_THRESH
      case value
      when 0..150   then "★★★"
      when 151..300 then "★★"
      when 301..500 then "★"
      else "—"
      end
    end
  end

  def self.star_or_nil(value, thresholds)
    s = stars_for(value, thresholds)
    s == "—" ? nil : s
  end

  class API
    def initialize(json_path:)
      @data  = JSON.parse(File.read(json_path))
      @index = build_index(@data)
    end

    def call(env)
      req = Rack::Request.new(env)

      return [200, headers_json, [JSON.dump(ok: true)]] if req.request_method == "GET" && req.path_info == "/health"
      return [200, headers_json, [JSON.dump(legend_json)]] if req.request_method == "GET" && req.path_info == "/legend"
      return [200, {}, []] if req.options?

      if req.request_method == "GET" && req.path_info == "/monsters"
        return handle_monsters(req)
      elsif req.request_method == "GET" && req.path_info == "/monster"
        return handle_monster(req)
      else
        return [404, headers_json, [JSON.dump(error: "not found")]]
      end
    rescue => e
      [500, headers_json, [JSON.dump(error: e.class.name, message: e.message)]]
    end

    private

    # ---------- /legend ----------
    def legend_json
      {
        weapons: WEAPON_KEYS.map { |k| { key: k, label: k.capitalize, icon: WEAPON_ICONS[k] } },
        elements: ELEM_KEYS.map { |k| { key: k, label: k.capitalize, icon: ELEM_ICONS[k] } },
        statuses: STATUS_ICONS.map { |k,v| { key: k, label: k.split('_').map(&:capitalize).join(' '), icon: v } },

        thresholds: {
          raw: {
            one:    MHGU::RAW_THRESH[:one],    # ≥ one  => ★
            two:    MHGU::RAW_THRESH[:two],    # ≥ two  => ★★
            three:  MHGU::RAW_THRESH[:three]   # ≥ three=> ★★★
          },
          element: {
            one:    MHGU::ELM_THRESH[:one],
            two:    MHGU::ELM_THRESH[:two],
            three:  MHGU::ELM_THRESH[:three]
          },
          status_initial: {
            # For statuses, lower initial = more vulnerable
            three_max: 150, # ≤ 150 => ★★★
            two_max:   300, # 151–300 => ★★
            one_max:   500  # 301–500 => ★
          }
        },

        notes: [
          "Weapons: cut/blunt/shot use RAW thresholds (higher is better).",
          "Elements use ELEMENT thresholds (higher is better).",
          "Statuses use initial build-up values (lower is better).",
          "Any value below ★ threshold is omitted in outputs."
        ]
      }
    end

    # ---------- /monsters (list) ----------
    def handle_monsters(req)
      q      = (req.params["q"] || "").downcase.strip
      limit  = (req.params["limit"] || "9999").to_i
      offset = (req.params["offset"] || "0").to_i
      limit  = 1 if limit < 1
      offset = 0 if offset < 0

      items = if q.empty?
        @index
      else
        @index.select { |m| m[:name].downcase.include?(q) || m[:slug].downcase.include?(q) }
      end

      total = items.size
      page  = items.slice(offset, limit) || []

      [200, headers_json, [JSON.dump({ count: page.size, total: total, offset: offset, limit: limit, items: page })]]
    end

    def build_index(data)
      (data["monsters"] || {}).values.map do |m|
        name = m["name"] || m["slug"] || "Monster"
        slug = (m["slug"] || name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, ""))
        { name: name, slug: slug, url: m["url"], api_url: "/monster?name=#{Rack::Utils.escape(slug)}" }
      end.sort_by { |m| m[:name] }
    end

    # ---------- /monster (detail) ----------
    def handle_monster(req)
      name    = req.params["name"].to_s.downcase
      stars   = req.params["stars"].to_s
      as_json = req.params["format"].to_s.downcase == "json"
      return [400, headers_json, [JSON.dump(error: "missing ?name=")]] if name.empty?

      mon = find_mon(@data, name)
      return [404, headers_json, [JSON.dump(error: "monster not found: #{name}")]] unless mon

      case stars
      when "1"
        if as_json
          body = build_stars_json(mon)          # A/B JSON with summaries
          [200, headers_json, [JSON.dump(body)]]
        else
          text = build_stars_text(mon)          # A/B text
          [200, headers_text, [text]]
        end
      when "2"
        if as_json
          body = build_collapsed_json(mon)      # Collapsed JSON with summaries
          [200, headers_json, [JSON.dump(body)]]
        else
          text = build_collapsed_text(mon)      # Collapsed text
          [200, headers_text, [text]]
        end
      else
        [200, headers_json, [JSON.dump(simple_json(mon))]]  # default: clean JSON
      end
    end

    # ---------- JSON (no stars) ----------
    def simple_json(mon)
      hit  = mon["hit_data"] || {}
      tabs = {}
      %w[A B].each do |tab|
        rows = hit[tab]
        next unless rows && !rows.empty?
        cleaned = rows.map { |r| scrub_part_hash(r) }.reject { |h| h.keys == [:part] }
        tabs[tab] = cleaned unless cleaned.empty?
      end
      {
        name: mon["name"],
        slug: mon["slug"],
        url:  mon["url"],
        tabs: tabs,
        status: scrub_status(mon["abnormal_status"] || {})
      }
    end

    def scrub_part_hash(r)
      out = { part: (r["part"] || r["Body Part"]) }
      (WEAPON_KEYS + ELEM_KEYS).each do |k|
        v = r[k]
        out[k.to_sym] = v if v.is_a?(Numeric) && v > 0
      end
      out
    end

    def scrub_status(status_hash)
      status_hash.select { |_k,v| v["initial"].is_a?(Numeric) && v["initial"] > 0 }
    end

    # ---------- TEXT: stars=1 (A/B) ----------
    def build_stars_text(mon)
      name = mon["name"]
      hit  = mon["hit_data"] || {}
      out  = []

      hit.each do |tab, rows|
        next if rows.nil? || rows.empty?
        out << "#{name} — #{tab}"
        out << ""

        rows.each do |r|
          part = r["part"] || r["Body Part"]

          raw_block = WEAPON_KEYS.map { |k|
            v = r[k]; s = MHGU.star_or_nil(v, RAW_THRESH); s ? "#{WEAPON_ICONS[k]}#{s}" : nil
          }.compact.join(" ")

          elem_block = ELEM_KEYS.map { |k|
            v = r[k]; s = MHGU.star_or_nil(v, ELM_THRESH); s ? "#{ELEM_ICONS[k]}#{s}" : nil
          }.compact.join(" ")

          segments = [raw_block, elem_block].reject { |s| s.nil? || s.empty? }
          out << "#{part}: #{segments.join(' | ')}"
        end
        out << ""

        st_line = format_status_line(mon["abnormal_status"])
        out << "Status: #{st_line}" unless st_line.empty?
      end

      out.join("\n")
    end

    # ---------- TEXT: stars=2 (collapsed) ----------
    def build_collapsed_text(mon)
      name = mon["name"]
      hit  = mon["hit_data"] || {}
      merged_rows = merge_tabs(hit["A"], hit["B"])
      return "#{name}\n(No hitzone data)" if merged_rows.empty?

      out = []
      out << "#{name} — Combined"
      out << ""

      merged_rows.each do |r|
        part = r["part"] || r["Body Part"]

        raw_block = WEAPON_KEYS.map { |k|
          v = r[k]; s = MHGU.star_or_nil(v, RAW_THRESH); s ? "#{WEAPON_ICONS[k]}#{s}" : nil
        }.compact.join(" ")

        elem_block = ELM_KEYS.map { |k|
          v = r[k]; s = MHGU.star_or_nil(v, ELM_THRESH); s ? "#{ELEM_ICONS[k]}#{s}" : nil
        }.compact.join(" ")

        segments = [raw_block, elem_block].reject { |s| s.nil? || s.empty? }
        out << "#{part}: #{segments.join(' | ')}"
      end
      out << ""

      st_line = format_status_line(mon["abnormal_status"])
      out << "Status: #{st_line}" unless st_line.empty?

      out.join("\n")
    end

    # ---------- JSON: stars=1 (A/B with summaries) ----------
    def build_stars_json(mon)
      body = { name: mon["name"], slug: mon["slug"], url: mon["url"], tabs: {} }
      hit  = mon["hit_data"] || {}

      %w[A B].each do |tab|
        rows = hit[tab]
        next unless rows && !rows.empty?

        elem_key = best_element_key(rows)
        best_raw  = top_for_key_with_stars(rows, "cut", RAW_THRESH, 3).map  { |x| { part: x[:part], value: x[:val], stars: x[:star], icon: WEAPON_ICONS["cut"] } }
        best_elem = top_for_key_with_stars(rows, elem_key, ELM_THRESH, 2).map { |x| { part: x[:part], value: x[:val], stars: x[:star] } }

        parts = rows.map { |r| part_entry_with_stars(r) }.reject { |h| h[:raw].empty? && h[:element].empty? }

        body[:tabs][tab] = {
          best_raw: best_raw,
          best_elem: { element: elem_key, icon: ELEM_ICONS[elem_key], top: best_elem },
          parts: parts,
          status: status_array(mon["abnormal_status"])
        }
      end

      body
    end

    # ---------- JSON: stars=2 (collapsed with summaries) ----------
    def build_collapsed_json(mon)
      body = { name: mon["name"], slug: mon["slug"], url: mon["url"] }
      hit  = mon["hit_data"] || {}
      merged_rows = merge_tabs(hit["A"], hit["B"])

      parts = merged_rows.map { |r| part_entry_with_stars(r) }.reject { |h| h[:raw].empty? && h[:element].empty? }

      best_weapons = WEAPON_KEYS.map do |k|
        x = top_for_key_with_stars(merged_rows, k, RAW_THRESH, 1).first
        x ? { type: k, icon: WEAPON_ICONS[k], part: x[:part], value: x[:val], stars: x[:star] } : nil
      end.compact

      best_elements = ELEM_KEYS.map do |k|
        x = top_for_key_with_stars(merged_rows, k, ELM_THRESH, 1).first
        x ? { element: k, icon: ELEM_ICONS[k], part: x[:part], value: x[:val], stars: x[:star] } : nil
      end.compact

      body[:header] = { best_weapons: best_weapons, best_elements: best_elements }
      body[:parts]  = parts
      body[:status] = status_array(mon["abnormal_status"])
      body
    end

    def part_entry_with_stars(r)
      part = r["part"] || r["Body Part"]
      raw_vals = {}
      WEAPON_KEYS.each do |k|
        v = r[k]
        raw_vals[k.to_sym] = v if v.is_a?(Numeric) && v > 0
      end
      elem_vals = {}
      ELEM_KEYS.each do |k|
        v = r[k]
        elem_vals[k.to_sym] = v if v.is_a?(Numeric) && v > 0
      end

      stars = {}
      raw_vals.each  { |k,v| stars[k] = MHGU.stars_for(v, RAW_THRESH) }
      elem_vals.each { |k,v| stars[k] = MHGU.stars_for(v, ELM_THRESH) }

      { part: part, raw: raw_vals, element: elem_vals, stars: stars }
    end

    def status_array(status_hash)
      return [] if status_hash.nil? || status_hash.empty?
      out = []
      status_hash.each do |k,v|
        init = v["initial"]
        next unless init.is_a?(Numeric) && init > 0
        s = MHGU.star_or_nil(init, STATUS_THRESH)
        next unless s
        out << { key: k, icon: (STATUS_ICONS[k.downcase] || k), initial: init, stars: s }
      end
      out
    end

    def format_status_line(status_hash)
      arr = status_array(status_hash)
      return "" if arr.empty?
      arr.map { |h| "#{h[:icon]}#{h[:stars]}" }.join(" ")
    end

    # ---------- helpers ----------
    def best_element_key(rows)
      best_key, best_val = nil, -1
      ELM_KEYS.each do |k|
        vals = rows.map { |r| r[k] }.select { |v| MHGU.star_or_nil(v, ELM_THRESH) }
        v = vals.max || 0
        if v > best_val
          best_val = v
          best_key = k
        end
      end
      best_key || "ice"
    end

    def top_for_key_with_stars(rows, key, thr, n)
      rows.map { |r|
        v = r[key]
        s = MHGU.star_or_nil(v, thr)
        s ? { part: (r["part"] || r["Body Part"]), val: v, star: s } : nil
      }.compact.sort_by { |h| -h[:val] }.first(n)
    end

    def merge_tabs(rows_a, rows_b)
      rows_a = Array(rows_a)
      rows_b = Array(rows_b)
      by_part = {}

      (rows_a + rows_b).each do |r|
        part = r["part"] || r["Body Part"]
        next if part.to_s.empty?
        by_part[part] ||= base_row(part)
        (WEAPON_KEYS + ELEM_KEYS).each do |k|
          v = r[k]; next unless v.is_a?(Numeric)
          prev = by_part[part][k]
          by_part[part][k] = prev.is_a?(Numeric) ? [prev, v].max : v
        end
      end

      order = (rows_a + rows_b).map { |r| r["part"] || r["Body Part"] }.compact.uniq
      order.map { |p| by_part[p] }.compact
    end

    def base_row(part)
      { "part"=>part }.merge(Hash[(WEAPON_KEYS + ELEM_KEYS).map { |k| [k, nil] }])
    end

    def find_mon(data, q)
      mons = data["monsters"] || {}
      mons.values.find { |m| (m["name"]||"").downcase == q || (m["slug"]||"").downcase == q } ||
      mons.values.find { |m| (m["name"]||"").downcase.include?(q) }
    end

    def headers_json
      { "Content-Type" => "application/json" }
    end

    def headers_text
      { "Content-Type" => "text/plain; charset=utf-8" }
    end
  end
end
