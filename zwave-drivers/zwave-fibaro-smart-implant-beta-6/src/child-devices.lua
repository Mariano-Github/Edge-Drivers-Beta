-- Module to create Zwave child LAN device thermostat
-- M. Colmenarejo 2022

local child_devices = {}

-- Create child device
function child_devices.create_new(driver, device, component, profile_type)

  local label = component .. "- Thermostat-".. device.label
  if component == "in1" then
    label = device.label .. "- Binary Input-1"
  elseif component == "in2" then
    label = device.label .. "- Binary Input-2"
  elseif component == "out1" then
    label = device.label .."- Switch Output-1"
  elseif component == "out2" then
      label = device.label .."- Switch Output-2"
  elseif component == "analog1" then
        label = device.label .. "- Analog Input-1"
  elseif component == "analog2" then
    label = device.label .. "- Analog Input-2"
  end
  
    if not device:get_child_by_parent_assigned_key(component) then
        
        local metadata = {
          type = "EDGE_CHILD",
          label = label,                              -- Initial Label for Child device
          profile = profile_type,                     -- Profile assigned to Child device created
          parent_device_id = device.id,               -- used to save parent device ID
          parent_assigned_child_key = component,      -- used as libraries parent_assigned_child_key                  
          vendor_provided_label = device.label        -- used to save parent label it if need
        }
        -- Create new device
        driver:try_create_device(metadata)

      end
end

return child_devices