require "json"
require_relative './helpers'

module MHGUMonsters
  def self.call(req, monster_index)
    if req.request_method == "GET" && req.path_info == "/api/v1/monsters"
      query      = (req.params["q"] || "").to_s.downcase.strip
      limit  = (req.params["limit"] || "9999").to_i
      offset = (req.params["offset"] || "0").to_i
      limit  = 1 if limit < 1
      offset = 0 if offset < 0
      filtered_items = if query.empty?
        monster_index
      else
        monster_index.select { |monster| monster[:name].downcase.include?(query) || monster[:slug].downcase.include?(query) }
      end

      total = filtered_items.size
      page_items  = filtered_items.slice(offset, limit) || []

      [200, { "Content-Type" => "application/json" }, [JSON.dump({ count: page_items.size, total: total, offset: offset, limit: limit, items: page_items })]]
    else
      nil
    end
  end
end
