-- M. Colmenarejo 2022
-- Modified to use EDGE_CHILD type

local child_devices = {}

local total_child = 0

-- Total child devices control
local function total_child_devices(driver, device, component)
  total_child = 0
  for uuid, dev in pairs(device.driver:get_devices()) do
    if dev:get_child_by_parent_assigned_key(component) ~= nil then
      total_child = total_child + 1
    end
  end
end

-- Create child device
function child_devices.create_new_device(driver, device, component, profile_type)
    -- check if child devices are < 10
    total_child_devices(driver, device, component)
    if total_child > 10 then return end

    local label = "Mirror Group Control-"..device.label
      if not device:get_child_by_parent_assigned_key(component) then
        print("<<< total Child devices >>>", total_child)
        local metadata = {
            type = "EDGE_CHILD", 
            label = label,                              -- Initial Label for Child device
            profile = profile_type,                     -- Profile assigned to Child device created
            parent_device_id = device.id,               -- used to save parent device ID
            parent_assigned_child_key = component,      -- used as libraries parent_assigned_child_key
            vendor_provided_label = label               -- Initial Label for Child devic
        }
        
        -- Create new device
        driver:try_create_device(metadata)

      end

end

  return child_devices