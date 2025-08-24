require "json"
require_relative './helpers'

module MHGUMonster
  def self.call(req, data)
    if req.request_method == "GET" && req.path_info == "/monster"
      name    = req.params["name"].to_s.downcase
      stars   = req.params["stars"].to_s
      as_json = req.params["format"].to_s.downcase == "json"
      return [400, { "Content-Type" => "application/json" }, [JSON.dump(error: "missing ?name=")]] if name.empty?

      mon = find_mon(data, name)
      return [404, { "Content-Type" => "application/json" }, [JSON.dump(error: "monster not found: #{name}")]] unless mon

      case stars
      when "1"
        if as_json
          body = build_stars_json(mon)
          [200, { "Content-Type" => "application/json" }, [JSON.dump(body)]]
        else
          text = build_stars_text(mon)
          [200, { "Content-Type" => "text/plain; charset=utf-8" }, [text]]
        end
      when "2"
        if as_json
          body = build_collapsed_json(mon)
          [200, { "Content-Type" => "application/json" }, [JSON.dump(body)]]
        else
          text = build_collapsed_text(mon)
          [200, { "Content-Type" => "text/plain; charset=utf-8" }, [text]]
        end
      else
        [200, { "Content-Type" => "application/json" }, [JSON.dump(simple_json(mon))]]
      end
    else
      nil
    end
  end

  # ...existing code for build_stars_text, build_collapsed_text, build_stars_json, build_collapsed_json, simple_json, and helpers...
  # These should be moved from app.rb to here, using MHGUHelpers where needed.
end
