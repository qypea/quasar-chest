function setup_inventory(inventory)
    -- Update our inventory filter for new items that mods may have provided
    -- For each not hidden item prototype
    local index = 1
    for item_name, item_value in pairs(prototypes.item) do
        if item_value.hidden == true or item_value.parameter == true then
            goto continue
        end

        -- Set one slot per quality level
        for quality_name, quality_value in pairs(prototypes.quality) do
            if quality_name == "quality-unknown" then
                goto continue2
            end
            -- If disabled, set just for normal quality
            if quality_name ~= "normal" and settings.startup["quasar-chest-all-qualities"].value == false then
                goto continue2
            end
            if inventory.set_filter(index, { name = item_name, quality = quality_name, comparitor = "=" }) == false then
                log("Set filter failed")
                return
            end
            index = index + 1
            ::continue2::
        end

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
    storage.chest_initialized = false
end

script.on_configuration_changed(on_init)
script.on_init(on_init)

function setup_player(player)
    -- Enable logistics requests panel in inventory, trash slots.
    -- Note that this enables logi bots to try to help with inventory, but
    -- they won't usually be able to. Probably best to not create logi bots.
    player.force.character_logistic_requests = true
    if player.force.character_trash_slot_count < 10 then
        player.force.character_trash_slot_count = 10
    end
end

function try_move(in_inv, out_inv, item, count)
    --log(string.format("try_move item=%s, count=%s", item, count))
    -- Limit to what is available to move
    local available = in_inv.get_item_count(item)
    if available < count then
        count = available
    end

    if count == 0 then
        return false
    end

    -- Try to add first, as that can fail if inv is full or whatnot
    local added = out_inv.insert({ name = item, count = count })
    if added == 0 then
        return false
    end

    -- Now remove only what we successfully added
    local removed = in_inv.remove({ name = item, count = added })

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
    -- link_id 0 with nullius or stock?
    local quasar_inv = player.force.get_linked_inventory("quasar-chest", 0)
    if quasar_inv == nil then
        log("No linked inventory")
        return
    end

    setup_player(player)

    if storage.chest_initialized == false then
        setup_inventory(quasar_inv)
        storage.chest_initialized = true
    end

    local logistics = player.get_requester_point()
    for _, request in ipairs(logistics.filters or {}) do
        local player_count = player_inv.get_item_count(request.name) + player_ammo.get_item_count(request.name)

        if player.cursor_stack ~= nil and player.cursor_stack.valid_for_read and player.cursor_stack.name == request.name then
            -- Skip trying to fill things into inventory when we have that
            -- thing in hand. Avoids constantly overfilling items we're
            -- currently placing.
            goto continue
        end

        if request.count ~= nil and player_count < request.count then
            try_move(quasar_inv, player_inv, request.name, request.count - player_count)
            -- Doesn't matter if we succeed or not. Try again next tick
        end

        -- request.max always is max-uint, a really big number We'll have to
        -- deal with that using the trash inventory instead

        ::continue::
    end

    local player_trash = player.get_inventory(defines.inventory.character_trash)
    for _, item in ipairs(player_trash.get_contents()) do
        -- Try to move from trash to quasar network
        local moved_some = try_move(player_trash, quasar_inv, item.name, item.count)

        -- If unable to move anything, throw it all away
        -- Allows us to feed things slowly into quasar chest if they're being
        -- consumed.
        if moved_some == false then
            player_trash.remove({ name = item.name, count = item.count })
        end
    end
end

script.on_nth_tick(120, logistics_tick)
