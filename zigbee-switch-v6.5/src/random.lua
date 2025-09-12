--- Smartthings library load ---
local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local Groups = zcl_clusters.Groups

local data_types = require "st.zigbee.data_types"
local write_attribute = require "st.zigbee.zcl.global_commands.write_attribute"
local zcl_messages = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local zb_const = require "st.zigbee.constants"
--local json = require "st.json"


---- Load handlers written in random.lua
local driver_handler = {}

--- Device running and update preferences variables
local device_running = {}

-- Random tables variables
local random_timer = {}

local last_signal_emit_time = os.time()

-- Custom Capability Randon On Off
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local energy_Reset = capabilities["legendabsolute60149.energyReset1"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]
--local driver_Version = capabilities["legendabsolute60149.driverVersion1"]

------- Write attribute ----
local function write_attribute_function(device, cluster_id, attr_id, data_value)
  local write_body = write_attribute.WriteAttribute({
   write_attribute.WriteAttribute.AttributeRecord(attr_id, data_types.ZigbeeDataType(data_value.ID), data_value.value)})

   local zclh = zcl_messages.ZclHeader({
     cmd = data_types.ZCLCommandId(write_attribute.WriteAttribute.ID)
   })
   local addrh = messages.AddressHeader(
       zb_const.HUB.ADDR,
       zb_const.HUB.ENDPOINT,
       device:get_short_address(),
       device:get_endpoint(cluster_id.value),
       zb_const.HA_PROFILE_ID,
       cluster_id.value
   )
   local message_body = zcl_messages.ZclMessageBody({
     zcl_header = zclh,
     zcl_body = write_body
   })
   device:send(messages.ZigbeeMessageTx({
     address_header = addrh,
     body = message_body
   }))
end

 --- return endpoint from component_id
local function component_to_endpoint(device, component_id)
  print("<<<<< device.fingerprinted_endpoint_id >>>>>>",device.fingerprinted_endpoint_id)
  if component_id == "main" then
    return 2
  else
    return 1
  end
end

--- return Component_id from endpoint
local function endpoint_to_component(device, ep)
  print("<<<<< device.fingerprinted_endpoint_id >>>>>>",device.fingerprinted_endpoint_id)
  if ep == 2 then
    return "main"
  else
    return "endpoint2"
  end
end

----- do_init device tables create for dimming variables ----
function driver_handler.do_init (self, device)
  print("<<< Device do_init >>>")
  
  if device:get_manufacturer() == "Quirky" and device:get_model() == "Smart Switch" then
    --This device has endpoint 1 and endpoint 2 is the main component 
    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)
  end

  ---- If is new device initialize table values
    device_running[device]= device
    random_timer[device] = math.random(10, 20)

  ------ Change profile & Icon
  if device:get_manufacturer() == "Quirky" and device:get_model() == "Smart Switch" then
    device:try_update_metadata({profile = "single-light-endpoint2"})
  else
    if device.preferences.changeProfile == "Switch" then
      device:try_update_metadata({profile = "single-switch"})
    elseif device.preferences.changeProfile == "SwitchOnly" then
      device:try_update_metadata({profile = "mhcozy-switch"})
    elseif device.preferences.changeProfile == "SwitchTemp" then
      device:try_update_metadata({profile = "mhcozy-switch-temp"})
    elseif device.preferences.changeProfile == "SwitchTempHumid" then
      device:try_update_metadata({profile = "mhcozy-switch-temp-humidity"})
    elseif device.preferences.changeProfile == "Plug" then
      device:try_update_metadata({profile = "single-switch-plug"})
    elseif device.preferences.changeProfile == "Light" then
      device:try_update_metadata({profile = "single-switch-light"})
    elseif device.preferences.changeProfile == "Vent" then
      device:try_update_metadata({profile = "switch-vent"})
    elseif device.preferences.changeProfile == "Camera" then
      device:try_update_metadata({profile = "switch-camera"})
    elseif device.preferences.changeProfile == "Humidifier" then
      device:try_update_metadata({profile = "switch-humidifier"})
    elseif device.preferences.changeProfile == "Air" then
    device:try_update_metadata({profile = "switch-air"})
    elseif device.preferences.changeProfile == "Tv" then
      device:try_update_metadata({profile = "switch-tv"})
    elseif device.preferences.changeProfile == "Oven" then
      device:try_update_metadata({profile = "switch-oven"})
    elseif device.preferences.changeProfile == "Refrigerator" then
      device:try_update_metadata({profile = "switch-refrigerator"})
    elseif device.preferences.changeProfile == "Washer" then
      device:try_update_metadata({profile = "switch-washer"})
    elseif device.preferences.changeProfile == "Irrigation" then
      device:try_update_metadata({profile = "switch-irrigation"})
    elseif device.preferences.changeProfileBatt1 == "Battery1" then
      device:try_update_metadata({profile = "switch-battery-light"})
    elseif device.preferences.changeProfileBatt == "Fingerbot" then
      device:try_update_metadata({profile = "switch-battery"})
    end 
  end

  -- initialice total energy and restart timer if is ON 
  if device:get_field("power_time_ini") == nil then device:set_field("power_time_ini", os.time(), {persist = false}) end

  if device.preferences.logDebugPrint == true then
    print("Last_energy_Total >>>>>",device:get_latest_state("main", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME))
    local energy_Total = device:get_latest_state("main", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
    print("energy_Total >>>>>",energy_Total)
    print("power_meter_timer >>>>>>>",device:get_field("power_meter_timer"))
  end

  local energy_Total = device:get_latest_state("main", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
  if energy_Total == nil then 
      energy_Total = 0 --end
    device:set_field("energy_Total", energy_Total, {persist = false})
    local energy_event = tonumber(string.format("%.3f",energy_Total))
    device:emit_event(capabilities.energyMeter.energy({value = energy_event, unit = "kWh" }))
  else
    device:set_field("energy_Total", energy_Total, {persist = false})
  end
  if device:get_field("powerTimer_Changed") == nil then device:set_field("powerTimer_Changed", "No", {persist = false}) end

  local cap_status = device:get_latest_state("main", energy_Reset.ID,energy_Reset.energyReset.NAME)
  if cap_status == nil then
    local date_reset = "Last: ".. string.format("%.3f",device:get_field("energy_Total")).." kWh".." ".."("..os.date("%m/%d/%Y",os.time() + device.preferences.localTimeOffset * 3600)..")"
    device:set_field("date_reset", date_reset, {persist = false})
    device:emit_event(energy_Reset.energyReset(date_reset))
  end

  --restart timer for power calcalation)
  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" and device.preferences.loadPower > 0 then
     -- read zigbee event
    energy_Total = device:get_field("energy_Total") + ((device.preferences.loadPower * device.preferences.powerTimer / 60 / 1000) / 2)
    device:set_field("energy_Total", energy_Total, {persist = false})
    local energy_event = tonumber(string.format("%.3f",energy_Total))
    device:emit_event_for_endpoint("main", capabilities.energyMeter.energy({value = energy_event, unit = "kWh" }))
    device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))
  end
  device:set_field("power_meter_timer", "OFF", {persist = false})

  -- init for random on-off 
  if device.preferences.logDebugPrint == true then
    print("<<<< random_state >>>>>",device:get_field("random_state"))
  end

  cap_status = device:get_latest_state("main", random_On_Off.ID, random_On_Off.randomOnOff.NAME)
  if cap_status == nil then
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    device:set_field("random_state", "Inactive", {persist = false})
  else
    device:set_field("random_state", cap_status, {persist = false})
    cap_status = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
      if cap_status == nil then
        device:emit_event(random_Next_Step.randomNext("Inactive"))
      end
      if cap_status ~= "Inactive" then
        -- convert string next change to seconds of date type
        local date = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
        local hour = tonumber(string.sub (date, 1 , 2))
        local min = tonumber(string.sub (date, 4 , 5))
        local sec = tonumber(string.sub (date, 7 , 8))
        local year = tonumber(os.date("%Y", os.time() + device.preferences.localTimeOffset * 3600))
        local month = tonumber(os.date("%m", os.time() + device.preferences.localTimeOffset * 3600))
        local day = tonumber(os.date("%d", os.time() + device.preferences.localTimeOffset * 3600))
        local time = os.time({ day = day, month = month, year = year, hour = hour, min = min, sec = sec})
        if device.preferences.logDebugPrint == true then
          print("<<< date:", date)
          print("<<< date:", year, month, day, hour, min, sec)
          print("<<< date formated >>>", os.date("%Y/%m/%d %H:%M:%S",time))
        end
        device:set_field("time_nextChange", time, {persist = false})
      end
  end

  ----- print device init values for debug------
  if device.preferences.logDebugPrint == true then
    local id = device
    print("device_running[id]=",device_running[id])
    print("random_timer=",random_timer[id])
  end

  --- special cofigure for this device, read attribute on-off every 120 sec and not configure reports
  if device:get_manufacturer() == "_TZ3000_9hpxg80k" then

    --- Configure basic cluster, attributte 0x0099 to 0x1
    local data_value = {value = 0x01, ID = 0x20}
    local cluster_id = {value = 0x0000}
    local attr_id = 0x0099
    write_attribute_function(device, cluster_id, attr_id, data_value)


    print("<<<<<<<<<<< read attribute >>>>>>>>>>>>>")
    device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))

    ---- Timers Cancel ------
      for timer in pairs(device.thread.timers) do
        print("<<<<< Cancelando timer >>>>>")
        device.thread:cancel_timer(timer)
     end
    --- Refresh atributte read schedule
    device.thread:call_on_schedule(
    120,
    function ()
      if device:get_manufacturer() == "_TZ3000_9hpxg80k" then
        print("<<< Timer read attribute >>>")
        device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))
      end
    end,
    'Refresh schedule') 
  end

  --restart random on-off if active
  if device.preferences.logDebugPrint == true then
    print("random_state >>>>>",device:get_field("random_state"))
  end
  if device:get_field("random_state") ~= "Inactive" then
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      device:set_field("last_state", "on")
    else
      device:set_field("last_state", "off")
    end
    driver_handler.random_on_off_handler(self,device,"Active")
  end

  -- Configure OnOff monitoring attribute
  local interval =  device.preferences.onOffReports
  if  device.preferences.onOffReports == nil then interval = 300 end
  --interval = 600
  --print("<< Custom max interval in init:", interval)
  local config ={
    cluster = zcl_clusters.OnOff.ID,
    attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
    minimum_interval = 0,
    maximum_interval = interval,
    data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
  }
  --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, device.preferences.onOffReports))
  device:add_configured_attribute(config)
  device:add_monitored_attribute(config)
  --device:remove_monitored_attribute(0x0006, 0x0000)

  if device:supports_capability_by_id(capabilities.battery.ID) then
    cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.type.NAME)
    if cap_status == nil and device.preferences.batteryType ~= nil then
      device:emit_event(capabilities.battery.type(device.preferences.batteryType))
    end

    cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.quantity.NAME)
    if cap_status == nil and device.preferences.batteryQuantity ~= nil then
      device:emit_event(capabilities.battery.quantity(device.preferences.batteryQuantity))
    end
  end
end

---- do_removed device procedure: delete all device data
function driver_handler.do_removed(self,device)
  for id, value in pairs(device_running) do
    if device_running[id] == device then
    device_running[device] =nil
    random_timer[device] = nil
   end
  end
  
  -----print tables of devices no removed from driver ------
  if device.preferences.logDebugPrint == true then
    for id, value in pairs(device_running) do
      print("device_running[id]",device_running[id])
      print("device_running, random_timer=",device_running[id],random_timer[id])
    end
  end
end

--- Update preferences after infoChanged recived---
function driver_handler.do_Preferences (self, device, event, args)
  print("<< do_Prefrences >>")
  for id, value in pairs(device.preferences) do
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      print("<< Preference changed name:",id, "old value:",oldPreferenceValue, "new value:", newParameterValue)
 
      --- Groups code preference value changed
      if id == "groupAdd" then
        if device.preferences[id] > 0 then
        print("Add Groups >>>>>>>>>>>>>>>>>")
        local data = device.preferences[id]
        device:send(Groups.server.commands.AddGroup(device, data, "Group"..tostring(data)))
        device:send(Groups.server.commands.GetGroupMembership(device, {}))
        else
        device:send(Groups.server.commands.GetGroupMembership(device, {}))
        end
        break
      elseif id == "groupRemove" then
        print("Remove Groups >>>>>>>>>>>>>>>>>")
        if device.preferences[id] > 0 then
        device:send(Groups.server.commands.RemoveGroup(device, device.preferences[id]))
        else
        device:send(Groups.server.commands.RemoveAllGroups(device, {}))
        end
        device:send(Groups.server.commands.GetGroupMembership(device, {}))
        break
      end

        ------ Change profile & Icon
        if id == "changeProfile" and device:get_manufacturer() ~= "Quirky" and device:get_model() ~= "Smart Switch" then
          if newParameterValue == "Switch" then
            device:try_update_metadata({profile = "single-switch"})
          elseif newParameterValue == "SwitchOnly" then
            device:try_update_metadata({profile = "mhcozy-switch"})
          elseif newParameterValue == "SwitchTemp" then
            device:try_update_metadata({profile = "mhcozy-switch-temp"})
          elseif newParameterValue == "SwitchTempHumid" then
            device:try_update_metadata({profile = "mhcozy-switch-temp-humidity"})
          elseif newParameterValue == "Plug" then
            device:try_update_metadata({profile = "single-switch-plug"})
          elseif newParameterValue == "Light" then
            device:try_update_metadata({profile = "single-switch-light"})
          elseif newParameterValue == "Vent" then
            device:try_update_metadata({profile = "switch-vent"})
          elseif newParameterValue == "Camera" then
            device:try_update_metadata({profile = "switch-camera"})
          elseif newParameterValue == "Humidifier" then
            device:try_update_metadata({profile = "switch-humidifier"})
          elseif newParameterValue == "Air" then
            device:try_update_metadata({profile = "switch-air"})
          elseif newParameterValue == "Tv" then
            device:try_update_metadata({profile = "switch-tv"})
          elseif newParameterValue == "Oven" then
            device:try_update_metadata({profile = "switch-oven"})
          elseif newParameterValue == "Refrigerator" then
            device:try_update_metadata({profile = "switch-refrigerator"})
          elseif newParameterValue == "Washer" then
            device:try_update_metadata({profile = "switch-washer"})
          elseif newParameterValue == "Irrigation" then
            device:try_update_metadata({profile = "switch-irrigation"})
          end
          break
        --- Preference power timer changed
        elseif id == "powerTimer" then
          if device:get_field("power_meter_timer") == "ON" then 
            device:set_field("powerTimer_Changed", "Yes", {persist = false})
          end
          break
          -- Any Preference timer mode changed restart timer handler
        elseif id == "randomMin" or id == "randomMax" or id == "onTime" or id == "offTime" then
          if device:get_field("random_state") ~= "Inactive" then  
            driver_handler.random_on_off_handler(self,device,"Active")
          end
          break
        elseif id == "onOffReports" then
          -- Configure OnOff interval report
          local interval =  device.preferences.onOffReports
          if  device.preferences.onOffReports == nil then interval = 300 end
          local config ={
            cluster = zcl_clusters.OnOff.ID,
            attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
            minimum_interval = 0,
            maximum_interval = interval,
            data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
          }
          device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, interval))
          device:add_monitored_attribute(config)
          break
        --- Configure on-off cluster, attributte 0x8002 and 4003 to value restore state in preferences
        elseif id == "restoreState" then
          print("<<< Write restore state >>>")
          local value_send = tonumber(newParameterValue)
          local data_value = {value = value_send, ID = 0x30}
          local cluster_id = {value = 0x0006}
          --write atribute for standard devices
          local attr_id = 0x4003
          write_attribute_function(device, cluster_id, attr_id, data_value)

          --write atribute for Tuya devices (Restore previous state = 0x02)
          if newParameterValue == "255" then data_value = {value = 0x02, ID = 0x30} end
          attr_id = 0x8002
          write_attribute_function(device, cluster_id, attr_id, data_value)
          break
        elseif id == "batteryType" and newParameterValue ~= nil then
          device:emit_event(capabilities.battery.type(newParameterValue))
        elseif id == "batteryQuantity" and newParameterValue ~= nil then
          device:emit_event(capabilities.battery.quantity(newParameterValue))
        end
      end
  end

  -- ********* Emit event for new driver version availabale ********

  --local new_version = "New Driver Version 6 Available: " .. os.date("%Y:%m:%d",os.time())
  --print("new_version >>>>>",new_version)
  --device:emit_event(driver_Version.driverVersion(new_version))

  -- ***************************************************************

  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)
  local firmware_full_version = device.data.firmwareFullVersion
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

----------------------------------------------------------
-- Save energy comsuption ------------------------
local function save_energy(self, device)

   device:emit_event_for_endpoint("main", capabilities.powerMeter.power({value = 0, unit = "W" }))

   --- Energy calculation
   local power_time = (os.time() - device:get_field("power_time_ini")) / 3600
   local energy_Total = device:get_field("energy_Total") + (power_time * device.preferences.loadPower / 1000)
   local energy_event = tonumber(string.format("%.3f",energy_Total))
   device:emit_event_for_endpoint("main", capabilities.energyMeter.energy({value = energy_event, unit = "kWh" }))
   device:set_field("energy_Total", energy_Total, {persist = false})
   device:set_field("power_time_ini", os.time(), {persist = false})

   -- calculate  capabilities.powerConsumptionReport
  local delta_energy = 0.0
  local current_power_consumption = device:get_latest_state("main", capabilities.powerConsumptionReport.ID, capabilities.powerConsumptionReport.powerConsumption.NAME)
  if device.preferences.logDebugPrint == true then
    print("<<< current_power_consumption >>>",current_power_consumption.energy)
  end
  if current_power_consumption ~= nil then
    delta_energy = math.max((energy_Total * 1000) - current_power_consumption.energy, 0.0)
  end
  device:emit_event(capabilities.powerConsumptionReport.powerConsumption({energy = energy_Total * 1000, deltaEnergy = delta_energy })) -- the unit of these values should be 'Wh'
end

---------------------------------------------------------
----on_off_attr_handler
function driver_handler.on_off_attr_handler(self, device, value, zb_rx)
  local set_status_timer = device:get_field("timer_power")

  if device.preferences.logDebugPrint == true then
    print("value.value >>>>>>>>>>>", value.value)
  end
  -- for sonnof mini messages bad data type Uint8 values
  if value.value == 0 then
    value.value = false
  elseif value.value == 1 then
    value.value = true
  end
  if device.preferences.logDebugPrint == true then
    print("New value.value >>>>>>>>>>>", value.value)
  end
  --print("LQI >>>>>",zb_rx.lqi.value)
  --print("RSSI >>>>>",zb_rx.rssi.value)
  --print (string.format("src_Address: 0x%04X", zb_rx.address_header.src_addr.value))

  if os.time() - last_signal_emit_time > 28 then
    local visible_satate = false
    if device.preferences.signalMetricsVisibles == "Yes" then
      visible_satate = true
    end

    local gmt = os.date("%Y/%m/%d Time: %H:%M",os.time() + device.preferences.localTimeOffset * 3600)
    local metrics = gmt .. ", LQI: ".. zb_rx.lqi.value .." ... rssi: ".. zb_rx.rssi.value

    device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))
    last_signal_emit_time = os.time()
  end

 if value.value == false or value.value == true then -- this is for correct a dupplicated message state in sonnof mini
  if device.preferences.logDebugPrint == true then
    print("<<<<<<< Power meter Timer >>>>>", device:get_field("power_meter_timer"))
  end
  local attr = capabilities.switch.switch
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())

  --- Calculate power and energy
  if value.value == false and device:get_field("last_state") == "on" then

    -- save power consumption
    device:set_field("last_state", "off", {persist = false})
    save_energy(self, device)
    
    if device:get_field("random_state") == "Inactive" then
    ---- Timers Cancel ------
        for timer in pairs(device.thread.timers) do
        print("<<<<< Cancelando timer >>>>>")
        device:set_field("power_meter_timer", "OFF", {persist = false})
        device.thread:cancel_timer(timer)
        end 
    end
  elseif value.value == false then
    device:emit_event_for_endpoint("main", capabilities.powerMeter.power({value = 0, unit = "W" }))
  elseif value.value == true then --- switch turn On
  --re-start power_time_ini if previous state is off
   if device:get_field("last_state") == "off" then device:set_field("power_time_ini", os.time(), {persist = false}) end
   device:set_field("last_state", "on", {persist = false})

   -- start power consumption
   local power = device.preferences.loadPower
   device:emit_event_for_endpoint("main", capabilities.powerMeter.power({value = power, unit = "W" }))

  ------ Timer activation
  if device:get_field("power_meter_timer") ~= "ON" and device.preferences.loadPower > 0 then

    device:set_field("power_time_ini", os.time(), {persist = false})

    device:set_field("power_meter_timer", "ON", {persist = false})
    set_status_timer = device.thread:call_on_schedule(
    device.preferences.powerTimer * 60,
    function ()
      print("<<<<<<<<<< TIMER >>>>>>>")

      if device:get_field("last_state") == "on" then
        power = device.preferences.loadPower
        --- Energy calculation
        local power_time = (os.time() - device:get_field("power_time_ini")) / 3600
        device:set_field("power_time_ini", os.time(), {persist = false})
        device:emit_event_for_endpoint("main", capabilities.powerMeter.power({value = power, unit = "W" }))
        local energy_Total = device:get_field("energy_Total") + (power_time * power / 1000)
        local energy_event = tonumber(string.format("%.3f",energy_Total))
        device:emit_event_for_endpoint("main", capabilities.energyMeter.energy({value = energy_event, unit = "kWh" }))
        device:set_field("energy_Total", energy_Total, {persist = false})

        -- calculate  capabilities.powerConsumptionReport
        local delta_energy = 0.0
        local current_power_consumption = device:get_latest_state("main", capabilities.powerConsumptionReport.ID, capabilities.powerConsumptionReport.powerConsumption.NAME)
        if device.preferences.logDebugPrint == true then
          print("<<< current_power_consumption >>>",current_power_consumption.energy)
        end
        if current_power_consumption ~= nil then
          delta_energy = math.max((energy_Total * 1000) - current_power_consumption.energy, 0.0)
        end
        device:emit_event(capabilities.powerConsumptionReport.powerConsumption({energy = energy_Total * 1000, deltaEnergy = delta_energy })) -- the unit of these values should be 'Wh'

        ---- re-start timer if preferences changed
        if device:get_field("powerTimer_Changed") == "Yes" then
          device:set_field("powerTimer_Changed", "No", {persist = false})
          set_status_timer = device:get_field("timer_power")
          if set_status_timer then
            print("<<<<< Cancelando Power timer >>>>>")
            device.thread:cancel_timer(set_status_timer)
            device:set_field("timer_power", nil)
            device:set_field("power_meter_timer", "OFF", {persist = false})
            device:send_to_component("main",zcl_clusters.OnOff.attributes.OnOff:read(device))
          end
        end
      end
    end
    ,'Power')
    device:set_field("timer_power", set_status_timer)
   end 
  end
 end
end

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function driver_handler.random_on_off_handler(self,device,command)

  local delay= {} -- variable to timer or random on or off period
  local set_status_timer = device:get_field("timer_random")
  if set_status_timer then
    print("<<<<< Cancelando timer_random >>>>>")
    device.thread:cancel_timer(set_status_timer)
    device:set_field("timer_random", nil)
  end
  if command ~= "Active" then
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" or command.args.value == "Inactive" then
      set_status_timer = device:get_field("timer_power")
      if set_status_timer then
        print("<<<<< Cancelando Power timer >>>>>")
        device.thread:cancel_timer(set_status_timer)
        device:set_field("timer_power", nil)
        device:set_field("power_meter_timer", "OFF", {persist = false})
      end
    end
  end
  
  local random_state = device:get_field("random_state")
  local nextChange = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
  if command == "Active" then
    --random_state = "Active"
    random_state = device:get_field("random_state")
  else
    random_state = command.args.value
  end

  if random_state == "Inactive" then
    device:set_field("time_nextChange", 0, {persist = false})
    -- send zigbee event
    device:send(OnOff.server.commands.Off(device))
    device:set_field("last_state", "off", {persist = false})
    device:emit_event(random_On_Off.randomOnOff("Inactive"))

    --emit time for next change
    nextChange = "Inactive"
    device:emit_event(random_Next_Step.randomNext(nextChange))
    device:set_field("random_state", "Inactive", {persist = false})
    device:set_field("time_nextChange", nil, {persist = false})
    save_energy(self, device)

  elseif random_state == "Random" or random_state == "Program" then
    device:emit_event(random_On_Off.randomOnOff(random_state))
    if random_state ~= device:get_field("random_state") then
      device:set_field("time_nextChange", nil, {persist = false})
    end

    device:set_field("random_state", random_state, {persist = false})

    if random_state == "Random" then
      --Random timer calculation
      random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
    else
      if device:get_field("last_state") == "on" then
        --Program timer calculation
        random_timer[device] = device.preferences.onTime * 60
      else
        --Program timer calculation
        random_timer[device] = device.preferences.offTime * 60
      end
    end

    -- calculate next time to change and timer delay
    if device:get_field("time_nextChange") == nil then
      nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
      local time_nextChange = os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600
      device:set_field("time_nextChange", time_nextChange, {persist = false})
      delay[device] = (os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600) - (os.time() + device.preferences.localTimeOffset * 3600)
    else
      delay[device] = device:get_field("time_nextChange") - (os.time() + device.preferences.localTimeOffset * 3600)
    end
    if delay[device] < 0.5 then delay[device] = 0.5 end

    --emit time for next change
    device:emit_event(random_Next_Step.randomNext(nextChange))
    if device.preferences.logDebugPrint == true then
      print("<<< delay[device]=",delay[device])
      print("NextChange=",nextChange)
      print("time_nextChange", os.date("%H:%M:%S",device:get_field("time_nextChange")))
    end

    ------ Timer activation
    set_status_timer = device.thread:call_with_delay(
      delay[device],
    function ()

        if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
          device:send(OnOff.server.commands.Off(device))
          device:set_field("last_state", "off", {persist = false})
          save_energy(self, device)
        else
          device:send(OnOff.server.commands.On(device))
          device:set_field("power_time_ini", os.time(), {persist = false})
          device:set_field("last_state", "on", {persist = false})
        end

        device:set_field("time_nextChange", nil, {persist = false})
        driver_handler.random_on_off_handler(self, device, "Active")
    end
  ,'Random-ON-OFF')
  device:set_field("timer_random", set_status_timer)
 end
end

  return driver_handler