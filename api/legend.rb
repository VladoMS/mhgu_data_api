require "json"
require_relative './helpers'

module MHGULegend
  def self.call(req)
    if req.request_method == "GET" && req.path_info == "/legend"
      [200, { "Content-Type" => "application/json" }, [JSON.dump(legend_json)]]
    else
      nil
    end
  end

  def self.legend_json
    {
      weapons: MHGUHelpers::WEAPON_KEYS.map { |k| { key: k, label: k.capitalize, icon: MHGUHelpers::WEAPON_ICONS[k] } },
      elements: MHGUHelpers::ELEM_KEYS.map { |k| { key: k, label: k.capitalize, icon: MHGUHelpers::ELEM_ICONS[k] } },
      statuses: MHGUHelpers::STATUS_ICONS.map { |k,v| { key: k, label: k.split('_').map(&:capitalize).join(' '), icon: v } },
      thresholds: {
        raw: MHGUHelpers::RAW_THRESH,
        element: MHGUHelpers::ELM_THRESH,
        status_initial: {
          three_max: 150,
          two_max: 300,
          one_max: 500
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
end
