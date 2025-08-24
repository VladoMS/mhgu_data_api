# Shared constants and helper methods for MHGU API
module MHGUHelpers
  RAW_THRESH = { one: 25, two: 35, three: 45 }
  ELM_THRESH = { one: 10, two: 20, three: 25 }
  STATUS_THRESH = { one: 300, two: 150, three: 0 }

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
end
