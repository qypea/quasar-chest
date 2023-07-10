function setup_inventory()
    -- Update our inventory filter for new items that mods may have provided
    if global.inventory_setup == true then
        return
    end

    -- Get access to the global shared inventory
    local player = game.get_player(1)
    local force = player.force
    local inventory = force.get_linked_inventory("quasar-chest", 0)

    -- For each not hidden item prototype
    local index = 1
    for item_name, item_value in pairs(game.item_prototypes) do
        if item_value.flags and item_value.flags["hidden"] == true then
            goto continue
        end

        -- Set one slot to filter for it
        inventory.set_filter(index, item_name)
        index = index + 1

        ::continue::
    end

    -- Set bar so no unfiltered slots can be filled with junk
    inventory.set_bar(index)

    -- Clear to ensure nothing is in the wrong slots. Unfortunately this means
    -- that you don't want to store things in this inventory when changing
    -- mods or mod settings.
    inventory.clear()

    global.inventory_setup = true
end


function configuration_changed()
    -- Force an upgrade of inventory settings
    global.inventory_setup = false
    setup_inventory()
end

script.on_configuration_changed(configuration_changed)

function player_created(event)
    -- Enable logistics requests panel in inventory, disable logi robots
    -- messing with it.
    local player = game.players[event.player_index]

    player.force.character_logistic_requests = true
    if player.character then
        player.character_personal_logistic_requests_enabled = false
    end

    -- Set up inventory if we get here and it isn't ready
    setup_inventory()
end
script.on_event(defines.events.on_player_created, player_created)
script.on_event(defines.events.on_player_joined_game, player_created)
