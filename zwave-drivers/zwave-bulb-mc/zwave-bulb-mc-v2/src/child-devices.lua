-- Child devices create module
local capabilities = require "st.capabilities"
local child_devices = {}

-- Create child device
function child_devices.create_new(driver, device, component, profile_type)

    local label = component.."-"..device.label

    if not device:get_child_by_parent_assigned_key(component) then
      local metadata = {
        type = "EDGE_CHILD", 
        label = label,                              -- Initial Label for Child device
        profile = profile_type,                     -- Profile assigned to Child device created
        parent_device_id = device.id,               -- used to save parent device ID
        parent_assigned_child_key = component,      -- used as libraries parent_assigned_child_key
        vendor_provided_label = label               -- used as libraries device.vendor_provided_label
      }
        
        -- Create new device
        driver:try_create_device(metadata)

    end
end

---- added device
function child_devices.device_added(driver, device)
  print("<<<<< device_added in Child devices >>>>>>>")

  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    print("Adding EDGE_CHILD device...")
    print("device_network_id >>>",device.device_network_id)
    print("label >>>",device.label)
    print("parent_device_id >>>",device.parent_device_id)

    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    local parent_level = parent_device:get_latest_state(component, capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
    if parent_level == nil then parent_level = 0 end
      if parent_level > 0 then
        device:emit_event(capabilities.switch.switch.on())
      else
        device:emit_event(capabilities.switch.switch.off())
      end
      device:emit_event(capabilities.switchLevel.level(parent_level))
    else
    --device:refresh()
  end
end

return child_devices