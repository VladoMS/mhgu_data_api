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

      mon = find_mon(data, slug.downcase)
      return [404, { "Content-Type" => "application/json" }, [JSON.dump(error: "monster not found: #{name}")]] unless mon
  # Default to JSON; only plain text when ?format=plain
  is_plain = req.params["format"].to_s.downcase == "plain"

      if view == 'views' && subview == 'simple'
        if is_plain
          text = build_simple_text(mon)
          [200, { "Content-Type" => "text/plain; charset=utf-8" }, [text]]
        else
          body = build_simple_json(mon)
          [200, { "Content-Type" => "application/json" }, [JSON.dump(body)]]
        end
      else
        # default: JSON unless ?format=plain requested
        if is_plain
          text = build_simple_text(mon)
          [200, { "Content-Type" => "text/plain; charset=utf-8" }, [text]]
        else
          [200, { "Content-Type" => "application/json" }, [JSON.dump(simple_json(mon))]]
        end
      end
    else
      nil
    end
  end

  # ---------- JSON ----------
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
    (MHGUHelpers::WEAPON_KEYS + MHGUHelpers::ELEM_KEYS).each do |k|
      v = r[k]
      out[k.to_sym] = v if v.is_a?(Numeric) && v > 0
    end
    out
  end

  def scrub_status(status_hash)
    status_hash.select { |_k,v| v["initial"].is_a?(Numeric) && v["initial"] > 0 }
  end

  # ---------- Monster Data (A/B) ----------
  def build_stars_text(mon)
    name = mon["name"]
    hit  = mon["hit_data"] || {}
    out  = []

    hit.each do |tab, rows|
      next if rows.nil? || rows.empty?
      out << "#{name} — #{tab}"

      rows.each do |r|
        part = r["part"] || r["Body Part"]

        raw_block = MHGUHelpers::WEAPON_KEYS.map { |k|
          v = r[k]; s = MHGUHelpers.star_or_nil(v, MHGUHelpers::RAW_THRESH); s ? "#{MHGUHelpers::WEAPON_ICONS[k]}#{s}" : nil
        }.compact.join(" ")

        elem_block = MHGUHelpers::ELEM_KEYS.map { |k|
          v = r[k]; s = MHGUHelpers.star_or_nil(v, MHGUHelpers::ELM_THRESH); s ? "#{MHGUHelpers::ELEM_ICONS[k]}#{s}" : nil
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

  # ---------- TEXT: Monster Data (simple) ----------
  def build_simple_text(mon)
    # same as previous collapsed text behavior
    name = mon["name"]
    hit  = mon["hit_data"] || {}
    merged_rows = merge_tabs(hit["A"], hit["B"])
    return "#{name}\n(No hitzone data)" if merged_rows.empty?

    out = []
    merged_rows.each do |r|
      part = r["part"] || r["Body Part"]

      raw_block = MHGUHelpers::WEAPON_KEYS.map { |k|
        v = r[k]; s = MHGUHelpers.star_or_nil(v, MHGUHelpers::RAW_THRESH); s ? "#{MHGUHelpers::WEAPON_ICONS[k]}#{s}" : nil
      }.compact.join(" ")

      elem_block = MHGUHelpers::ELEM_KEYS.map { |k|
        v = r[k]; s = MHGUHelpers.star_or_nil(v, MHGUHelpers::ELM_THRESH); s ? "#{MHGUHelpers::ELEM_ICONS[k]}#{s}" : nil
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
      best_raw  = top_for_key_with_stars(rows, "cut", MHGUHelpers::RAW_THRESH, 3).map  { |x| { part: x[:part], value: x[:val], stars: x[:star], icon: MHGUHelpers::WEAPON_ICONS["cut"] } }
      best_elem = top_for_key_with_stars(rows, elem_key, MHGUHelpers::ELM_THRESH, 2).map { |x| { part: x[:part], value: x[:val], stars: x[:star] } }

      parts = rows.map { |r| part_entry_with_stars(r) }.reject { |h| h[:raw].empty? && h[:element].empty? }

      body[:tabs][tab] = {
        best_raw: best_raw,
        best_elem: { element: elem_key, icon: MHGUHelpers::ELEM_ICONS[elem_key], top: best_elem },
        parts: parts,
        status: status_array(mon["abnormal_status"])
      }
    end

    body
  end

  # ---------- JSON: stars=2 (simple with summaries) ----------
  def build_simple_json(mon)
    body = { name: mon["name"], slug: mon["slug"], url: mon["url"] }
    hit  = mon["hit_data"] || {}
    merged_rows = merge_tabs(hit["A"], hit["B"])

    parts = merged_rows.map { |r| part_entry_with_stars(r) }.reject { |h| h[:raw].empty? && h[:element].empty? }

    best_weapons = MHGUHelpers::WEAPON_KEYS.map do |k|
      x = top_for_key_with_stars(merged_rows, k, MHGUHelpers::RAW_THRESH, 1).first
      x ? { type: k, icon: MHGUHelpers::WEAPON_ICONS[k], part: x[:part], value: x[:val], stars: x[:star] } : nil
    end.compact

    best_elements = MHGUHelpers::ELEM_KEYS.map do |k|
      x = top_for_key_with_stars(merged_rows, k, MHGUHelpers::ELM_THRESH, 1).first
      x ? { element: k, icon: MHGUHelpers::ELEM_ICONS[k], part: x[:part], value: x[:val], stars: x[:star] } : nil
    end.compact

    body[:header] = { best_weapons: best_weapons, best_elements: best_elements }
    body[:parts]  = parts
    body[:status] = status_array(mon["abnormal_status"])
    body
  end

  def part_entry_with_stars(r)
    part = r["part"] || r["Body Part"]
    raw_vals = {}
    MHGUHelpers::WEAPON_KEYS.each do |k|
      v = r[k]
      raw_vals[k.to_sym] = v if v.is_a?(Numeric) && v > 0
    end
    elem_vals = {}
    MHGUHelpers::ELEM_KEYS.each do |k|
      v = r[k]
      elem_vals[k.to_sym] = v if v.is_a?(Numeric) && v > 0
    end

    stars = {}
    raw_vals.each  { |k,v| stars[k] = MHGUHelpers.stars_for(v, MHGUHelpers::RAW_THRESH) }
    elem_vals.each { |k,v| stars[k] = MHGUHelpers.stars_for(v, MHGUHelpers::ELM_THRESH) }

    { part: part, raw: raw_vals, element: elem_vals, stars: stars }
  end

  def status_array(status_hash)
    return [] if status_hash.nil? || status_hash.empty?
    out = []
    status_hash.each do |k,v|
      init = v["initial"]
      next unless init.is_a?(Numeric) && init > 0
      s = MHGUHelpers.star_or_nil(init, MHGUHelpers::STATUS_THRESH)
      next unless s
      out << { key: k, icon: (MHGUHelpers::STATUS_ICONS[k.downcase] || k), initial: init, stars: s }
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
    MHGUHelpers::ELEM_KEYS.each do |k|
      vals = rows.map { |r| r[k] }.select { |v| MHGUHelpers.star_or_nil(v, MHGUHelpers::ELM_THRESH) }
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
      s = MHGUHelpers.star_or_nil(v, thr)
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
      (MHGUHelpers::WEAPON_KEYS + MHGUHelpers::ELEM_KEYS).each do |k|
        v = r[k]; next unless v.is_a?(Numeric)
        prev = by_part[part][k]
        by_part[part][k] = prev.is_a?(Numeric) ? [prev, v].max : v
      end
    end

    order = (rows_a + rows_b).map { |r| r["part"] || r["Body Part"] }.compact.uniq
    order.map { |p| by_part[p] }.compact
  end

  def base_row(part)
    { "part"=>part }.merge(Hash[(MHGUHelpers::WEAPON_KEYS + MHGUHelpers::ELEM_KEYS).map { |k| [k, nil] }])
  end

  def find_mon(data, q)
    mons = data["monsters"] || {}
    mons.values.find { |m| (m["name"]||"").downcase == q || (m["slug"]||"").downcase == q } ||
    mons.values.find { |m| (m["name"]||"").downcase.include?(q) }
  end
end
