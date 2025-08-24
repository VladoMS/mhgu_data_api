require "json"
require_relative './helpers'

module MHGUMonsters
  def self.call(req, index)
    if req.request_method == "GET" && req.path_info == "/monsters"
      q      = (req.params["q"] || "").downcase.strip
      limit  = (req.params["limit"] || "9999").to_i
      offset = (req.params["offset"] || "0").to_i
      limit  = 1 if limit < 1
      offset = 0 if offset < 0

      items = if q.empty?
        index
      else
        index.select { |m| m[:name].downcase.include?(q) || m[:slug].downcase.include?(q) }
      end

      total = items.size
      page  = items.slice(offset, limit) || []

      [200, { "Content-Type" => "application/json" }, [JSON.dump({ count: page.size, total: total, offset: offset, limit: limit, items: page })]]
    else
      nil
    end
  end
end
