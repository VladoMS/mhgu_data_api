require "json"
require_relative './helpers'

module MHGUHealth
  def self.call(req)
    if req.request_method == "GET" && req.path_info == "/api/v1/health"
      [200, { "Content-Type" => "application/json" }, [JSON.dump(ok: true)]]
    else
      nil
    end
  end
end
