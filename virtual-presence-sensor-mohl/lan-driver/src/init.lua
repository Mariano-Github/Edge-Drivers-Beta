---- M. Colmenarejo 2022
-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

-- require custom handlers from driver package
local discovery = require "discovery"

local create_Device = capabilities["legendabsolute60149.createDevice"]
local location_Status = capabilities["legendabsolute60149.locationStatus"]

-- variables
local initialized = false
local total_device_running = 0

-----------------------------------------------------------------
-- local functions
-----------------------------------------------------------------

-- count total devices running
local function count_device_running(driver, device)
  local total_device = -1
  local device_main
  for uuid, dev in pairs(device.driver:get_devices()) do
    total_device = total_device + 1
    if dev.preferences.profileNumber == 0 then
      device_main = dev
    end
  end
  print("<<<<<< total_device_running:",total_device)
  local text = "Total Devices: ".. total_device
  device_main:emit_event(create_Device.createDevice(text))
  return total_device
end

-- preferences update
local function do_preferences(driver, device, event, args)
  for id, value in pairs(device.preferences) do
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      print("<< Preference changed name:", id, "Old Value:",oldPreferenceValue, "New Value:", newParameterValue)
      if id == "deviceOperationType" then
        if newParameterValue == "Presence" then
          local cap_status = device:get_latest_state("main", capabilities.presenceSensor.ID, capabilities.presenceSensor.presence.NAME)
          device:emit_event(location_Status.locationStatus(cap_status))
        elseif newParameterValue == "Location" then
          if device:get_latest_state("main", location_Status.ID, location_Status.locationStatus.NAME) == nil or device:get_field("LOCATION-STATUS") == nil then
          device:emit_event(location_Status.locationStatus("Waiting Status..."))
          -- save last locationStatus value
          device:set_field("LOCATION-STATUS", "Waiting Status...")
        else
          device:emit_event(location_Status.locationStatus(device:get_field("LOCATION-STATUS")))
        end
        end
      end
    end
  end
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- driver_Switched
local function driver_Switched (driver, device)

  --- initialize selected profile
    if device.preferences.profileNumber == 0 then
      device:try_update_metadata({profile = "creator-virtual-device"})
    elseif device.preferences.profileNumber == 1 then
      device:try_update_metadata({profile = "virtual-presence-sensor"})
    end
end

--- this is called once a device is added by the cloud and synchronized down to the hub
local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new Virtual Device")

  device.thread:call_with_delay(3, 
  function() 
  -- set a default or queried state for each capability attribute
    if device.preferences.profileNumber ~= nil then
      total_device_running = count_device_running(driver, device)
      if device.preferences.profileNumber == 0 then
        local text = "Total Devices: ".. total_device_running
        device:emit_event(create_Device.createDevice(text))
      end
    end
  end)
end

-- refresh handler
local function device_refresh(driver, device, command)

  if device.preferences.profileNumber == 0 and command ~= 0 then
    total_device_running = count_device_running(driver, device)
    local text = "Total Devices: "..total_device_running
    device:emit_event(create_Device.createDevice(text))
  end
end

-- this is called both when a device is added (but after `added`) and after a hub reboots.
local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- set initialized driver = true
   initialized = true

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })

  -- initialize selected profile
  if device.preferences.profileNumber ~= nil then
    if device.preferences.profileNumber == 0 then
      total_device_running = count_device_running(driver, device)
    elseif device.preferences.profileNumber == 1 then
      local cap_status = device:get_latest_state("main", capabilities.presenceSensor.ID, capabilities.presenceSensor.presence.NAME)
      if cap_status == nil then cap_status = "not present" end
      device:emit_event(capabilities.presenceSensor.presence(cap_status))
      if device.preferences.deviceOperationType == "Presence" then
        device:emit_event(location_Status.locationStatus(cap_status))
      elseif device.preferences.deviceOperationType == "Location" then
        if device:get_latest_state("main", location_Status.ID, location_Status.locationStatus.NAME) == nil or device:get_field("LOCATION-STATUS") == nil then
          device:emit_event(location_Status.locationStatus("Waiting Status..."))
          -- save last locationStatus value
          device:set_field("LOCATION-STATUS", "Waiting Status...")
        else
          device:emit_event(location_Status.locationStatus(device:get_field("LOCATION-STATUS")))
        end
      end
      cap_status = device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME)
      if cap_status == nil then 
        device:emit_event(capabilities.switch.switch.off())
      end
    end
  end
  
  device.thread:call_with_delay(2, function() device_refresh(driver, device, 0) end)
end

-- this is called when a device is removed by the cloud and synchronized down to the hub
local function device_removed(driver, device)
  log.info("[" .. device.id .. "] Removing Virtual Device")

  total_device_running = count_device_running(driver, device)

end

--create_Device_handler
local function create_device_handler(driver, device, command)

  print("<<< Create Device Type:", command.args.value)
  -- DeviceType variable is the name of the profile in preferences
  local profileNumber
  if command.args.value == "Create" then
   profileNumber = 1 -- Presence sensor
  else
    total_device_running = count_device_running(driver, device)
    local text = "Total Devices: "..total_device_running
    device:emit_event(create_Device.createDevice(text.." "))
    device:emit_event(create_Device.createDevice(text))
    return
  end

  total_device_running = total_device_running + 1
  discovery.handle_discovery(driver, profileNumber) -- Presence device

  local text = "Total Devices: "..total_device_running
  device:emit_event(create_Device.createDevice(text))

end

-- Discovery Main virtual device
local function discovery_handler(driver, _should_continue)

  if initialized == false then
    discovery.handle_discovery(driver, 0) --Creator device
    
  else
    log.info ('Discovery handler: already initialized; no action')
  end

  log.debug("Exiting device discovery")

end

-- callback to handle an on-off capability command
local function switch_on_off_handler(driver, device, command)
  print("<<<<<<<<<<<<<<<<<<<<<< On - Off Handler >>>>>>>>>>>>>>>>>>>>>>>")
  local presence_status = command.command
  if command.component == "main" then
    if presence_status == "on" then
      device:emit_event(capabilities.switch.switch.on())
      device:emit_event(capabilities.presenceSensor.presence("present"))
      if device.preferences.deviceOperationType == "Presence" then
        device:emit_event(location_Status.locationStatus("present"))
      elseif device.preferences.deviceOperationType == "Location" then
        if device:get_field("LOCATION-STATUS") == nil then device:set_field("LOCATION-STATUS", "Waiting Status ...") end
        device:emit_event(location_Status.locationStatus(device:get_field("LOCATION-STATUS")))
      end
    elseif presence_status == "off" then
      device:emit_event(capabilities.switch.switch.off())
      device:emit_event(capabilities.presenceSensor.presence("not present"))
      if device.preferences.deviceOperationType == "Presence" then
        device:emit_event(location_Status.locationStatus("not present"))
      elseif device.preferences.deviceOperationType == "Location" then
        if device:get_field("LOCATION-STATUS") == nil then device:set_field("LOCATION-STATUS", "Waiting Status ...") end
        device:emit_event(location_Status.locationStatus(device:get_field("LOCATION-STATUS")))
      end
    end
  end
end

--command_handlers.setTextField_One_handler
local function setlocation_Status_handler(driver, device, command)
  if device.preferences.deviceOperationType == "Location" then
    device:emit_event(location_Status.locationStatus(command.args.value))
    -- save last locationStatus value
    device:set_field("LOCATION-STATUS", command.args.value)
  elseif device.preferences.deviceOperationType == "Presence" then
    local cap_status = device:get_latest_state("main", capabilities.presenceSensor.ID, capabilities.presenceSensor.presence.NAME)
      if cap_status == nil then cap_status = "not present" end
      device:emit_event(location_Status.locationStatus(cap_status))
  end
end


-- this new function in libraries version 9 allow load only subdrivers with devices paired
  local function lazy_load_if_possible(sub_driver_name)
    -- gets the current lua libs api version
    local version = require "version"
  
    print("<<<<< Library Version:", version.api)
    -- version 9 will include the lazy loading functions
    if version.api >= 9 then
      return Driver.lazy_load_sub_driver(require(sub_driver_name))
    else
      return require(sub_driver_name)
    end
  end

-- create the driver object
local Virtual_Device_driver = Driver("VirtualDevice", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    driverSwitched = driver_Switched,
    infoChanged = do_preferences,
    removed = device_removed
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_on_off_handler,
      [capabilities.switch.commands.off.NAME] = switch_on_off_handler,
    },
    [create_Device.ID] = {
      [create_Device.commands.setCreateDevice.NAME] = create_device_handler
    },
    [location_Status.ID] = {
      [location_Status.commands.setLocationStatus.NAME] = setlocation_Status_handler
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_refresh,
    },
  },
  sub_drivers = {
    --lazy_load_if_possible("virtual-mirror-switch")
  },
  
})

-- run the driver
Virtual_Device_driver:run()
