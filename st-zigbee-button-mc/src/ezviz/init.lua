-- M. Colmenarejo 2023
-- use cluster 0xEF05 attribute 0x000 to send valjues 1= pushed, 2= pushed_2x y 3 = held

local capabilities = require "st.capabilities"

local can_handle = function(opts, driver, device)
    return device:get_manufacturer() == "EZVIZ"
end

local button_handler = function(driver, device, value, zb_rx)
    print("<<<< value.value=",value.value)
    
    local event
    local additional_fields = {
        state_change = true
    }
    if value.value == 3 then
        event = capabilities.button.button.held(additional_fields)
    elseif value.value == 1 then
        event = capabilities.button.button.pushed(additional_fields)
    elseif value.value == 2 then
        event = capabilities.button.button.double(additional_fields)
    end
    if event ~= nil then
        device:emit_event_for_endpoint(
        zb_rx.address_header.src_endpoint.value,
        event)
    end
end

local ezviz_button = {
	NAME = "ezviz button",
    zigbee_handlers = {
        attr = {
            [0xFE05] = {
              [0x0000] = button_handler
            }
        }
    },
    lifecycle_handlers = {
    },
	can_handle = can_handle
}

return ezviz_button
