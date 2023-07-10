function configuration_changed()
    -- Update our inventory filter for new items that mods may have provided

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
end

script.on_configuration_changed(configuration_changed)
