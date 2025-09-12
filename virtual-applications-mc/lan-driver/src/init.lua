---- M. Colmenarejo 2022
-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

-- require custom handlers from driver package
local command_handlers = require "command_handlers"
local discovery = require "discovery"
local random = require "virtual-mirror-switch.random"

local mirror_In = capabilities["legendabsolute60149.mirrorIn"]
local mirror_Out = capabilities["legendabsolute60149.mirrorOut"]
local name_Switch1 = capabilities["legendabsolute60149.nameSwitch1"]
local name_Switch2 = capabilities["legendabsolute60149.nameSwitch2"]
local name_Switch3 = capabilities["legendabsolute60149.nameSwitch3"]
local name_Switch4 = capabilities["legendabsolute60149.nameSwitch4"]
local name_Switch5 = capabilities["legendabsolute60149.nameSwitch5"]
local create_Device = capabilities["legendabsolute60149.createDevice2"]
local switchBoard_Type = capabilities["legendabsolute60149.switchBoardType"]
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]

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
    if dev.preferences.switchNumber == 0 then
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
    --print("device.preferences[infoChanged]=", device.preferences[id])
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:", id, "Old Value:",oldPreferenceValue, "New Value:", newParameterValue)
      if id == "switchBoardType" then
        local switch_Board = device.preferences.switchNumber .. " Independent Switches"
        if newParameterValue == "MaxOneSwitchOn" then
          switch_Board = device.preferences.switchNumber .. " Switches-Max 1 Switch On"
        end
        print("<<<< switch_Board:",switch_Board)
        device:emit_event(switchBoard_Type.switchBoardType({value = switch_Board}, {visibility = {displayed = false }}))
      elseif id == "changeProfile" then
        if newParameterValue == "Mirror" then
           device:try_update_metadata({profile = "virtual-only-mirror"})
        elseif device.preferences.changeProfile == "MirrorSwitch" then
           device:try_update_metadata({profile = "virtual-switch-mirror"})
        elseif device.preferences.changeProfile == "Switch" then
           device:try_update_metadata({profile = "virtual-only-switch"})
        end
        -- Any Preference timer mode changed restart timer handler
      elseif id == "randomMin" or id == "randomMax" or id == "onTime" or id == "offTime" then
        if device:get_field("random_state") ~= "Inactive" then  
          random.random_on_off_handler(driver,device,"Active")
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
    if device.preferences.switchNumber > 1 and device.preferences.switchNumber < 6 then
      device:try_update_metadata({profile = "switchboard-" .. device.preferences.switchNumber})

      local switch_Board = device.preferences.switchNumber .. " Independent Switches"
      if device.preferences.switchBoardType == "MaxOneSwitchOn" then
        switch_Board = device.preferences.switchNumber .. " Switches- Max 1 Switch On"
      end
      device:emit_event(switchBoard_Type.switchBoardType({value = switch_Board}, {visibility = {displayed = false }}))

    elseif device.preferences.switchNumber == 6 then
      device:try_update_metadata({profile = "text-field-5"})
    elseif device.preferences.switchNumber == 7 then
      device:try_update_metadata({profile = "number-field-5"})
    elseif device.preferences.switchNumber == 8 then
      device:try_update_metadata({profile = "virtual-calendar"})
    elseif device.preferences.switchNumber == 9 then
      device:try_update_metadata({profile = "virtual-timer-days"})
    elseif device.preferences.switchNumber == 10 then
      device:try_update_metadata({profile = "virtual-timer-seconds"})
    elseif device.preferences.switchNumber < 2 then
      if device.preferences.mirrorMain == "Yes" then
        device:try_update_metadata({profile = "main-virtual-device"})
        return
      end
      if device.preferences.changeProfile == "Mirror" then
        device:try_update_metadata({profile = "virtual-only-mirror"})
        return
      elseif device.preferences.changeProfile == "MirrorSwitch" then
        device:try_update_metadata({profile = "virtual-switch-mirror"})
        return
      elseif device.preferences.changeProfile == "Switch" then
        device:try_update_metadata({profile = "virtual-only-switch"})
      end
    end
end

--- this is called once a device is added by the cloud and synchronized down to the hub
local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new Virtual Device")

  device.thread:call_with_delay(3, 
  function() 
  -- set a default or queried state for each capability attribute
  if device.preferences.switchNumber ~= nil then
    total_device_running = count_device_running(driver, device)
    if device.preferences.switchNumber == 0 then
      local text = "Total Devices: ".. total_device_running
      device:emit_event(create_Device.createDevice(text))
    end
  end
end)
end

-- refresh handler
local function device_refresh(driver, device, command)

  if device.preferences.switchNumber == 0 and command ~= 0 then
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
  if device.preferences.switchNumber ~= nil then
    if device.preferences.switchNumber == 0 then
      total_device_running = count_device_running(driver, device)
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

  print("<<< Create SwitchBoard Type:", command.args.value)
  -- switchBoard variable is the number of the profile in preferences
  local switchBoard
  if command.args.value == "Virtual_Mirror_Switch" then
    switchBoard = 1
  elseif command.args.value == "SwitchBoard 2 Switches" or command.args.value == "SwitchBoard_2_Switches" then
    switchBoard = 2
  elseif command.args.value == "SwitchBoard 3 Switches" or command.args.value == "SwitchBoard_3_Switches"then
    switchBoard = 3
  elseif command.args.value == "SwitchBoard 4 Switches" or command.args.value == "SwitchBoard_4_Switches"then
    switchBoard = 4
  elseif command.args.value == "SwitchBoard 5 Switches" or command.args.value == "SwitchBoard_5_Switches"then
    switchBoard = 5
  elseif command.args.value == "TextField 5 Fields" or command.args.value == "TextField_5_Fields" then
    switchBoard = 6
  elseif command.args.value == "NumberField 5 Fields" or command.args.value == "NumberField_5_Fields" then
    switchBoard = 7
  elseif command.args.value == "Virtual Calendar" or command.args.value == "Virtual_Calendar" then
    switchBoard = 8
  elseif command.args.value == "Timer Number of Days" or command.args.value == "Timer_Number_of_Days" then
    switchBoard = 9
  elseif command.args.value == "Timer of Seconds" or command.args.value == "Timer_of_Seconds" then
    switchBoard = 10
  elseif command.args.value == "List_battery_devices" then
    switchBoard = 11
  elseif command.args.value == "List_device_events" then
    switchBoard = 12
  elseif command.args.value == "Virtual_security_device" then
    switchBoard = 13
  else
    total_device_running = count_device_running(driver, device)
    local text = "Total Devices: "..total_device_running
    device:emit_event(create_Device.createDevice(text.." "))
    device:emit_event(create_Device.createDevice(text))
    return
  end

  total_device_running = total_device_running + 1
  discovery.handle_discovery(driver, switchBoard)

  local text = "Total Devices: "..total_device_running
  device:emit_event(create_Device.createDevice(text))

end

-- Discovery Main virtual device
local function discovery_handler(driver, _should_continue)

  if initialized == false then
    discovery.handle_discovery(driver, 0)
    
  else
    log.info ('Discovery handler: already initialized; no action')
  end

  log.debug("Exiting device discovery")

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
      [capabilities.switch.commands.on.NAME] = command_handlers.switch_on_off_handler,
      [capabilities.switch.commands.off.NAME] = command_handlers.switch_on_off_handler,
    },
    [mirror_In.ID] = {
      [mirror_In.commands.setMirrorIn.NAME] = command_handlers.mirror_in
    },
    [mirror_Out.ID] = {
      [mirror_Out.commands.setMirrorOut.NAME] = command_handlers.mirror_out
    },
    [name_Switch1.ID] = {
      [name_Switch1.commands.setNameSwitchOne.NAME] = command_handlers.setNameSwitch_One_handler
    },
    [name_Switch2.ID] = {
      [name_Switch2.commands.setNameSwitchTwo.NAME] = command_handlers.setNameSwitch_Two_handler
    },
    [name_Switch3.ID] = {
      [name_Switch3.commands.setNameSwitchThree.NAME] = command_handlers.setNameSwitch_Three_handler
    },
    [name_Switch4.ID] = {
      [name_Switch4.commands.setNameSwitchFour.NAME] = command_handlers.setNameSwitch_Four_handler
    },
    [name_Switch5.ID] = {
      [name_Switch5.commands.setNameSwitchFive.NAME] = command_handlers.setNameSwitch_Five_handler
    },
    [create_Device.ID] = {
      [create_Device.commands.setCreateDevice.NAME] = create_device_handler
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_refresh,
    },
    [random_On_Off.ID] = {
      [random_On_Off.commands.setRandomOnOff.NAME] = random.random_on_off_handler,
    },
  },
  sub_drivers = {
    lazy_load_if_possible("virtual-security"),
    lazy_load_if_possible("virtual-calendar"),
    lazy_load_if_possible("virtual-battery-list"),
    lazy_load_if_possible("virtual-events-list"),
    lazy_load_if_possible("virtual-timer-days"),
    lazy_load_if_possible("virtual-timer-seconds"),
    lazy_load_if_possible("virtual-text-fields"),
    lazy_load_if_possible("virtual-number-fields"),
    lazy_load_if_possible("virtual-switch-board"),
    lazy_load_if_possible("virtual-mirror-switch")
  },
  
})

-- run the driver
Virtual_Device_driver:run()
