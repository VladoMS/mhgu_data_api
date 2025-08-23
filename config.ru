# rackup entry
require_relative "./app"
run MHGU::API.new(
  json_path: ENV.fetch("MONSTERS_JSON", File.expand_path("./monsters.json", __dir__))
)
