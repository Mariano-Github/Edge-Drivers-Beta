local log = require "log"
local discovery = {}

-- handle discovery events, normally you'd try to discover devices on your
-- network in a loop until calling `should_continue()` returns false.
function discovery.handle_discovery(driver, profileNumber)
  log.info("Starting Virtual Device Discovery")
  
  local profile = ""
  local label = "CREATOR Virtual Presence Sensor"
  local model = "CREATOR Virtual Presence Sensor"
  local device_network_id = "VirtualPresence-" .. os.time()
  if profileNumber == 0 then -- Creator device
    profile = "creator-virtual-device"
    model = "CREATOR Virtual Devices"
  elseif profileNumber == 1 then -- Presence sensor
    profile = "virtual-presence-sensor"
    label = "Virtual Presence Sensor-" .. os.time()
    model = "Virtual Presence Sensor"
  end

  local metadata = {
    type = "LAN",
    -- the DNI must be unique across your hub, using static ID here so that we
    -- only ever have a single instance of this "device"
    device_network_id = device_network_id,
    label = label,
    profile = profile,
    manufacturer = "MColmenarejo",
    model = model,
    vendor_provided_label = nil
  }

  -- tell the cloud to create a new device record, will get synced back down
  -- and `device_added` and `device_init` callbacks will be called
  driver:try_create_device(metadata)
end

return discovery
