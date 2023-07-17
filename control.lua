function setup_inventory(inventory)
    -- Update our inventory filter for new items that mods may have provided
    -- For each not hidden item prototype
    local index = 1
    for item_name, item_value in pairs(game.item_prototypes) do
        if item_value.flags and item_value.flags["hidden"] == true then
            goto continue
        end

        -- Set one slot to filter for it
        if inventory.set_filter(index, item_name) == false then
            log("Set filter failed")
            return
        end
        index = index + 1

        ::continue::
    end
    log(string.format("Set %d item filters", index))

    -- Set bar so no unfiltered slots can be filled with junk
    if inventory.set_bar(index) == false then
        log("Set bar failed")
    end

    -- Clear to ensure nothing is in the wrong slots. Unfortunately this means
    -- that you don't want to store things in this inventory when changing
    -- mods or mod settings.
    inventory.clear()
end

function on_init()
    -- Force rerunning setup
    global.chest_initialized = false
end
script.on_configuration_changed(on_init)
script.on_init(on_init)

function setup_player(player)
    -- Enable logistics requests panel in inventory, trash slots.
    -- Note that this enables logi bots to try to help with inventory, but
    -- they won't usually be able to. Probably best to not create logi bots.
    player.force.character_logistic_requests = true
    player.force.character_trash_slot_count = 10
    player.character_personal_logistic_requests_enabled = true
end

function try_move(in_inv, out_inv, item, count)
    -- Limit to what is available to move
    local available = in_inv.get_item_count(item)
    if available < count then
        count = available
    end

    if count == 0 then
        return false
    end

    -- Try to add first, as that can fail if inv is full or whatnot
    local added = out_inv.insert({name=item, count=count})
    if added == 0 then
        return false
    end

    -- Now remove only what we successfully added
    local removed = in_inv.remove({name=item, count=added})

    return added ~= 0
end

function logistics_tick()
    -- Update the player's inventory based on logistics requests
    local player = game.get_player(1)
    if player == nil then
        log("No player 1")
        return
    end
    if player.character == nil then
        log("No character connected to player 1")
        return
    end

    local player_inv = player.get_inventory(defines.inventory.character_main)
    if player_inv == nil then
        log("No player inventory")
        return
    end
    local player_ammo = player.get_inventory(defines.inventory.character_ammo)
    if player_ammo == nil then
        log("No player ammo")
        return
    end

    -- why are the chests I create link_id 3 with space-exploration but
    -- link_id 0 with nullius?
    local quasar_inv = player.force.get_linked_inventory("quasar-chest", 3)
    if quasar_inv == nil then
        log("No linked inventory")
        return
    end

    if global.player_initialized == false then
        setup_player(player)
        global.player_initialized = true
    end

    if global.chest_initialized == false then
        setup_inventory(quasar_inv)
        global.chest_initialized = true
    end

    for i=1,1000 do -- for each logistics slot index(Hard limited by factorio to 1000)
        local request = player.get_personal_logistic_slot(i)
        if request == nil or request.name == nil then
            goto continue
        end

        local player_count = player_inv.get_item_count(request.name) + player_ammo.get_item_count(request.name)

        if player.cursor_stack ~= nil and player.cursor_stack.valid_for_read and player.cursor_stack.name == request.name then
            -- Skip trying to fill things into inventory when we have that
            -- thing in hand. Avoids constantly overfilling items we're
            -- currently placing.
            goto continue
        end

        if request.min ~= nil and player_count < request.min then
            try_move(quasar_inv, player_inv, request.name, request.min - player_count)
            -- Doesn't matter if we succeed or not. Try again next tick
        end

        -- request.max always is max-uint, a really big number We'll have to
        -- deal with that using the trash inventory instead

        ::continue::
    end

    local player_trash = player.get_inventory(defines.inventory.character_trash)
    for item_name, count in pairs(player_trash.get_contents()) do
        -- Try to move from trash to quasar network
        local moved_some = try_move(player_trash, quasar_inv, item_name, count)

        -- If unable to move anything, throw it all away
        -- Allows us to feed things slowly into quasar chest if they're being
        -- consumed.
        if moved_some == false then
            player_trash.remove({name=item_name, count=count})
        end
    end
end
script.on_nth_tick(120, logistics_tick)
