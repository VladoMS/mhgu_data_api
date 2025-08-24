# frozen_string_literal: true

require "json"
require "rack"
require_relative "./api/helpers"
require_relative "./api/health"
require_relative "./api/legend"
require_relative "./api/monsters"
require_relative "./api/monster"


module MHGU
  class API
  def initialize(json_path:)
    @data  = JSON.parse(File.read(json_path))
    @index = build_index(@data)
  end

  def call(env)
    req = Rack::Request.new(env)

    # Delegate to endpoint modules
    resp = MHGUHealth.call(req)
    return resp if resp

    resp = MHGULegend.call(req)
    return resp if resp

    resp = MHGUMonsters.call(req, @index)
    return resp if resp

    resp = MHGUMonster.call(req, @data)
    return resp if resp

    return [404, { "Content-Type" => "application/json" }, [JSON.dump(error: "not found")]]
  rescue => e
    [500, { "Content-Type" => "application/json" }, [JSON.dump(error: e.class.name, message: e.message)]]
  end

  private
  def build_index(data)
    (data["monsters"] || {}).values.map do |m|
      name = m["name"] || m["slug"] || "Monster"
      slug = (m["slug"] || name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, ""))
      { name: name, slug: slug, url: m["url"], api_url: "/monster?name=#{Rack::Utils.escape(slug)}" }
    end.sort_by { |m| m[:name] }
  end
  end
end
