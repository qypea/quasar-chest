local chest = util.table.deepcopy(data.raw["linked-container"]["linked-chest"])
chest.name = "quasar-chest"
chest.minable.result = "quasar-chest"
chest.inventory_size = 10000 -- Trimmed in creation callback by setting bar
chest.inventory_type = "with_filters_and_bar"
chest.gui_mode = "none"

chest.circuit_wire_connection_point = circuit_connector_definitions["chest"].points
chest.circuit_connector_sprites = circuit_connector_definitions["chest"].sprites
chest.circuit_wire_max_distance = default_circuit_wire_max_distance

data:extend({
  chest,
  {
    type = "item",
    name = "quasar-chest",
    icon = "__base__/graphics/icons/linked-chest-icon.png",
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "storage",
    order = "a[items]-a[quasar-chest]",
    place_result = "quasar-chest",
    stack_size = 10
  },
  {
    type = "recipe",
    name = "quasar-chest",
    enabled = true,
    ingredients = {},
    result = "quasar-chest"
  }
})
