require "json"
require_relative './helpers'

module MHGUMonster
  module_function

  def call(req, data)
  # Expect paths like: /api/v1/monsters/:slug or /api/v1/monsters/:slug/views/simple
    if req.request_method == "GET" && req.path_info.start_with?("/api/v1/monsters")
      parts = req.path_info.sub(%r{^/api/v1/monsters/?}, "").split('/').reject(&:empty?)
      slug = parts[0]
  view = parts[1] # e.g. 'views'
  subview = parts[2] # e.g.'simple'

      return [400, { "Content-Type" => "application/json" }, [JSON.dump(error: "missing slug")]] if slug.to_s.empty?

  monster = find_mon(data, slug.downcase)
  return [404, { "Content-Type" => "application/json" }, [JSON.dump(error: "monster not found: #{slug}")]] unless monster
  # Default to JSON; only plain text when ?format=plain
  is_plain = req.params["format"].to_s.downcase == "plain"

      if view == 'views' && subview == 'simple'
        if is_plain
          text = build_simple_text(monster)
          [200, { "Content-Type" => "text/plain; charset=utf-8" }, [text]]
        else
          body = build_simple_json(monster)
          [200, { "Content-Type" => "application/json" }, [JSON.dump(body)]]
        end
      else
        # default: JSON unless ?format=plain requested
        if is_plain
          text = build_simple_text(monster)
          [200, { "Content-Type" => "text/plain; charset=utf-8" }, [text]]
        else
          [200, { "Content-Type" => "application/json" }, [JSON.dump(simple_json(monster))]]
        end
      end
    else
      nil
    end
  end

  # ---------- JSON ----------
  def simple_json(monster)
    hit_data  = monster["hit_data"] || {}
    tabs = {}
    %w[A B].each do |tab_name|
      rows = hit_data[tab_name]
      next unless rows && !rows.empty?
      cleaned = rows.map { |row| scrub_part_hash(row) }.reject { |h| h.keys == [:part] }
      tabs[tab_name] = cleaned unless cleaned.empty?
    end
    {
      name: monster["name"],
      slug: monster["slug"],
      url:  monster["url"],
      tabs: tabs,
      status: scrub_status(monster["abnormal_status"] || {})
    }
  end

  def scrub_part_hash(row)
    out = { part: (row["part"] || row["Body Part"]) }
    (MHGUHelpers::WEAPON_KEYS + MHGUHelpers::ELEM_KEYS).each do |key|
      value = row[key]
      out[key.to_sym] = value if value.is_a?(Numeric) && value > 0
    end
    out
  end

  def scrub_status(status_hash)
    status_hash.select { |_key,entry| entry["initial"].is_a?(Numeric) && entry["initial"] > 0 }
  end

  # ---------- JSON: stars=1 (A/B with summaries) ----------
  def build_stars_json(monster)
    body = { name: monster["name"], slug: monster["slug"], url: monster["url"], tabs: {} }
    hit_data  = monster["hit_data"] || {}

    %w[A B].each do |tab_name|
      rows = hit_data[tab_name]
      next unless rows && !rows.empty?

      elem_key = best_element_key(rows)
      best_raw  = top_for_key_with_stars(rows, "cut", MHGUHelpers::RAW_THRESH, 3).map  { |entry| { part: entry[:part], value: entry[:val], stars: entry[:star], icon: MHGUHelpers::WEAPON_ICONS["cut"] } }
      best_elem = top_for_key_with_stars(rows, elem_key, MHGUHelpers::ELM_THRESH, 2).map { |entry| { part: entry[:part], value: entry[:val], stars: entry[:star] } }

      parts = rows.map { |row| part_entry_with_stars(row) }.reject { |h| h[:raw].empty? && h[:element].empty? }

      body[:tabs][tab_name] = {
        best_raw: best_raw,
        best_elem: { element: elem_key, icon: MHGUHelpers::ELEM_ICONS[elem_key], top: best_elem },
        parts: parts,
        status: status_array(monster["abnormal_status"])
      }
    end

    body
  end

  # ---------- JSON: stars=2 (simple with summaries) ----------
  def build_simple_json(monster)
    body = { name: monster["name"], slug: monster["slug"], url: monster["url"] }
    hit_data  = monster["hit_data"] || {}
    merged_rows = merge_tabs(hit_data["A"], hit_data["B"])

    parts = merged_rows.map { |row| part_entry_with_stars(row) }.reject { |h| h[:raw].empty? && h[:element].empty? }

    best_weapons = MHGUHelpers::WEAPON_KEYS.map do |weapon_key|
      entry = top_for_key_with_stars(merged_rows, weapon_key, MHGUHelpers::RAW_THRESH, 1).first
      entry ? { type: weapon_key, icon: MHGUHelpers::WEAPON_ICONS[weapon_key], part: entry[:part], value: entry[:val], stars: entry[:star] } : nil
    end.compact

    best_elements = MHGUHelpers::ELEM_KEYS.map do |elem_key|
      entry = top_for_key_with_stars(merged_rows, elem_key, MHGUHelpers::ELM_THRESH, 1).first
      entry ? { element: elem_key, icon: MHGUHelpers::ELEM_ICONS[elem_key], part: entry[:part], value: entry[:val], stars: entry[:star] } : nil
    end.compact

    body[:header] = { best_weapons: best_weapons, best_elements: best_elements }
    body[:parts]  = parts
    body[:status] = status_array(monster["abnormal_status"])
    body
  end

  def part_entry_with_stars(row)
    part = row["part"] || row["Body Part"]
    raw_vals = {}
    MHGUHelpers::WEAPON_KEYS.each do |weapon_key|
      value = row[weapon_key]
      raw_vals[weapon_key.to_sym] = value if value.is_a?(Numeric) && value > 0
    end
    elem_vals = {}
    MHGUHelpers::ELEM_KEYS.each do |elem_key|
      value = row[elem_key]
      elem_vals[elem_key.to_sym] = value if value.is_a?(Numeric) && value > 0
    end

    stars = {}
    raw_vals.each  { |k,v| stars[k] = MHGUHelpers.stars_for(v, MHGUHelpers::RAW_THRESH) }
    elem_vals.each { |k,v| stars[k] = MHGUHelpers.stars_for(v, MHGUHelpers::ELM_THRESH) }

    { part: part, raw: raw_vals, element: elem_vals, stars: stars }
  end

  def status_array(status_hash)
    return [] if status_hash.nil? || status_hash.empty?
    out = []
    status_hash.each do |status_key,entry|
      initial_value = entry["initial"]
      next unless initial_value.is_a?(Numeric) && initial_value > 0
      star_str = MHGUHelpers.star_or_nil(initial_value, MHGUHelpers::STATUS_THRESH)
      next unless star_str
      out << { key: status_key, icon: (MHGUHelpers::STATUS_ICONS[status_key.downcase] || status_key), initial: initial_value, stars: star_str }
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
    MHGUHelpers::ELEM_KEYS.each do |elem_key|
      vals = rows.map { |row| row[elem_key] }.select { |value| MHGUHelpers.star_or_nil(value, MHGUHelpers::ELM_THRESH) }
      value = vals.max || 0
      if value > best_val
        best_val = value
        best_key = elem_key
      end
    end
    best_key || "ice"
  end

  def top_for_key_with_stars(rows, key, thr, n)
    rows.map { |row|
      value = row[key]
      star_str = MHGUHelpers.star_or_nil(value, thr)
      star_str ? { part: (row["part"] || row["Body Part"]), val: value, star: star_str } : nil
    }.compact.sort_by { |h| -h[:val] }.first(n)
  end

  def merge_tabs(rows_a, rows_b)
    rows_a = Array(rows_a)
    rows_b = Array(rows_b)
    by_part = {}

    (rows_a + rows_b).each do |row|
      part = row["part"] || row["Body Part"]
      next if part.to_s.empty?
      by_part[part] ||= base_row(part)
      (MHGUHelpers::WEAPON_KEYS + MHGUHelpers::ELEM_KEYS).each do |key|
        value = row[key]; next unless value.is_a?(Numeric)
        prev = by_part[part][key]
        by_part[part][key] = prev.is_a?(Numeric) ? [prev, value].max : value
      end
    end

    order = (rows_a + rows_b).map { |row| row["part"] || row["Body Part"] }.compact.uniq
    order.map { |p| by_part[p] }.compact
  end

  def base_row(part)
    { "part"=>part }.merge(Hash[(MHGUHelpers::WEAPON_KEYS + MHGUHelpers::ELEM_KEYS).map { |k| [k, nil] }])
  end

  def find_mon(data, query)
    mons = data["monsters"] || {}
    mons.values.find { |m| (m["name"]||"").downcase == query || (m["slug"]||"").downcase == query } ||
    mons.values.find { |m| (m["name"]||"").downcase.include?(query) }
  end
end
