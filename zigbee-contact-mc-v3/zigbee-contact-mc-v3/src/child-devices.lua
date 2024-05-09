-- Module to create child EDGE device
-- M. Colmenarejo 2022

local child_devices = {}

local total_child_batteries = 0

-- Total child devices control
local function total_child_devices(driver, device, component)
  total_child_batteries = 0
  for uuid, dev in pairs(device.driver:get_devices()) do
      --print("<<< Profile type:",dev.preferences.profileType)
      if dev.preferences.profileType == "Batteries" then
        total_child_batteries = total_child_batteries + 1
      end
  end
end

-- Create child device
function child_devices.create_new(driver, device, component, profile)
  local label = "Vibration-".. device.label
  if profile == "child-batteries-status" then
    total_child_devices(driver, device, component)
    --print("<<< Total_child_batteries:", total_child_batteries)
    if total_child_batteries > 0 then return end

    label = "Battery-Zibee Contact Mc"
  end

    if not device:get_child_by_parent_assigned_key(component) then

        local metadata = {
            type = "EDGE_CHILD",
            label = label,                              -- Initial Label for Child device
            profile = profile,                          -- Profile assigned to Child device created
            parent_device_id = device.id,               -- used to save parent device ID
            parent_assigned_child_key = component,      -- used as libraries parent_assigned_child_key
            vendor_provided_label = profile             -- used to save child device profile name it if need
        }
        
        -- Create new device
        driver:try_create_device(metadata)

      end

end

  return child_devices