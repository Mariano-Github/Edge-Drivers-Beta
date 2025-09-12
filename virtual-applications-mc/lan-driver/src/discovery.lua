local log = require "log"
local discovery = {}

-- handle discovery events, normally you'd try to discover devices on your
-- network in a loop until calling `should_continue()` returns false.
function discovery.handle_discovery(driver, counter)
  log.info("Starting Virtual Device Discovery")
  
  local profile = ""
  local label = "SwitchBoard-" .. os.time()
  local model = "VirtualDevices-v2"
  local device_network_id = "VirtualSwitchBoard-" .. os.time()
  if counter == 0 then
    profile = "main-virtual-device"
    label = "MAIN Virtual Devices"
    model = "MAIN Virtual Devices-V2"
  elseif counter == 1 then
    profile = "virtual-switch-mirror"
    label = "Virtual Mirror-" .. os.time()
    model = "Virtual Switch Mirror"
  elseif counter > 1 and  counter < 6 then
    profile = "switchboard-" .. counter
    label = "SwitchBoard-" .. counter .. " (" .. os.time() ..")"
    model = "Virtual Switchboard-" .. counter
  elseif counter == 6  then
    profile = "text-field-5"
    label = "Text Field" .. " (" .. os.time() ..")"
    model = "Virtual Text Field-5"
  elseif counter == 7  then
    profile = "number-field-5"
    label = "Number Field" .. " (" .. os.time() ..")"
    model = "Virtual Number Field-5"
  elseif counter == 8  then
    profile = "virtual-calendar"
    label = "Virtual Calendar Device" .. " (" .. os.time() ..")"
    model = "Virtual Calendar"
    device_network_id = "virtual calendar v1" .."-".. os.time()
  elseif counter == 9  then
    profile = "virtual-timer-days"
    label = "Timer Number Days" .. " (" .. os.time() ..")"
    model = "Virtual Timer Days"
    device_network_id = "timer days v1" .."-".. os.time()
  elseif counter == 10  then
    profile = "virtual-timer-seconds"
    label = "Timer Seconds" .. " (" .. os.time() ..")"
    model = "Virtual Timer Seconds"
    device_network_id = "timer seconds v1" .."-".. os.time()
  elseif counter == 11  then
    profile = "list-device-battery"
    label = "List Batteries" .. " (" .. os.time() ..")"
    model = "Virtual List Batteries"
    device_network_id = "list Batt v1" .."-".. os.time()
  elseif counter == 12  then
    profile = "list-device-events"
    label = "List Events" .. " (" .. os.time() ..")"
    model = "Virtual List Events"
    device_network_id = "list Event v1" .."-".. os.time()
  elseif counter == 13  then
    profile = "virtual-security"
    label = "Virtual Security" .. " (" .. os.time() ..")"
    model = "Virtual Security"
    device_network_id = "Virtual Security" .."-".. os.time()
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
