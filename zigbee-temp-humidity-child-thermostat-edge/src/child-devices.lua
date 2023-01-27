-- Module to create child LAN device
-- M. Colmenarejo 2022

local child_devices = {}

-- Create child device
function child_devices.create_new(driver, device, component)

    local label = "Thermostat-".. device.label
    local profile = "child-thermostat"

    if not device:get_child_by_parent_assigned_key(component) then

        local metadata = {
            type = "EDGE_CHILD",
            label = label,                              -- Initial Label for Child device
            profile = profile,                          -- Profile assigned to Child device created
            parent_device_id = device.id,               -- used to save parent device ID
            parent_assigned_child_key = component,      -- used as libraries parent_assigned_child_key
            vendor_provided_label = device.label        -- used to save parent label it if need
        }
        
        -- Create new device
        driver:try_create_device(metadata)

      end

end

  return child_devices