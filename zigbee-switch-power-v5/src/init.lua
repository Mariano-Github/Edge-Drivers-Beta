-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-------- Author Mariano Colmenarejo (Oct 2021)

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local ElectricalMeasurement = zcl_clusters.ElectricalMeasurement
local SimpleMetering = zcl_clusters.SimpleMetering
local utils = require "st.utils"
local Groups = zcl_clusters.Groups
local constants = require "st.zigbee.constants"
local device_management = require "st.zigbee.device_management"
local Status = require "st.zigbee.generated.types.ZclStatus"
local zcl_global_commands = require "st.zigbee.zcl.global_commands"
local data_types = require "st.zigbee.data_types"

-- driver local modules load
local random = require "random"
local write = require "writeAttribute"
local customDivisors = require "customDivisors"

--- Custom Capabilities
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

local set_status_timer


local function do_configure(self, device)
  print ("<<< do_configure >>>")
  
  if device.preferences.powerEnergyRead ~= nil then
  --if device:get_manufacturer() == "_TZ3000_9vo5icau" or -- this device does not send power and energy reports
    --device:get_manufacturer() == "_TZ3000_1h2x4akh" or
    ---device:get_manufacturer() == "_TZ3000_gvn91tmx" or
    --device:get_manufacturer() == "_TZ3000_okaz9tjs" or 
    --device:get_manufacturer() == "_TZ3000_g5xawfcq" then  

      -- power and energy configure reporting
      device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, self.environment_info.hub_zigbee_eui))
      device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 300)) --0, 120

      device:send(device_management.build_bind_request(device, zcl_clusters.ElectricalMeasurement.ID, self.environment_info.hub_zigbee_eui))
      device:send(zcl_clusters.ElectricalMeasurement.attributes.ActivePower:configure_reporting(device, 1, 3600, 5))
      device:send(device_management.build_bind_request(device, zcl_clusters.SimpleMetering.ID, self.environment_info.hub_zigbee_eui))
      device:send(zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:configure_reporting(device, 1, 3600, 5))
  
  else
    --device:configure()
    if device:get_manufacturer() == "Develco Products A/S" and  device:get_model() == "SPLZB-131" then
      print("Configure Device Temperature Configuration >>>>>>>>")

      device:send(device_management.build_bind_request(device, zcl_clusters.DeviceTemperatureConfiguration.ID, self.environment_info.hub_zigbee_eui):to_endpoint (2))
      --device:send(zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature:configure_reporting(device, 60, 600, 1):to_endpoint (2))

      local min = 30
      local max = 30
      local change = 1

      local config =
      {
        cluster = 0x0002,
        attribute = 0x0000,
        minimum_interval = min,
        maximum_interval = max,
        reportable_change = change,
        data_type = data_types.Uint16,
      }
      device:add_configured_attribute(config)
      device:add_monitored_attribute(config)

      device.thread:call_with_delay(3, function() 
        device:send(zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature:read(device):to_endpoint (2))
      end)
    end

    -- Configure OnOff interval report
    local config ={
      cluster = zcl_clusters.OnOff.ID,
      attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
      minimum_interval = 0,
      maximum_interval = device.preferences.onOffReports,
      data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
    }
    --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, device.preferences.onOffReports))
    device:add_configured_attribute(config)
    device:add_monitored_attribute(config)
    device:configure()

    -- Additional one time configuration
      -- Divisor and multipler for ElectricalMeasurement
      device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
      device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
      -- Divisor and multipler for SimpleMetering
      device:send(SimpleMetering.attributes.Divisor:read(device))
      device:send(SimpleMetering.attributes.Multiplier:read(device))
  end

  --- save optionals device divisors
  device.thread:call_with_delay(3, function() customDivisors.set_custom_divisors(self, device) end)

end

--- instantaneous_demand_handler
local function instantaneous_demand_handler(driver, device, value, zb_rx)
  print(">>>> Instantaneous demand handler")
  local raw_value = value.value
  --- demand = demand received * Multipler/Divisor
  local multiplier = device:get_field(constants.SIMPLE_METERING_MULTIPLIER_KEY) or 1
  local divisor = device:get_field(constants.SIMPLE_METERING_DIVISOR_KEY) or 1

  if divisor == 0 then 
    --log.warn("Temperature scale divisor is 0; using 1 to avoid division by zero")
    divisor = 1
  end
  
  if device.preferences.logDebugPrint == true then
    print("multiplier >>>>",multiplier)
    print("divisor >>>>>",divisor)
  end
  raw_value = raw_value * multiplier/divisor

  local raw_value_watts = raw_value * 1000
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.powerMeter.power({value = raw_value_watts, unit = "W" }))
end

--- energy_meter_handler
local function energy_meter_handler(driver, device, value, zb_rx)
  local raw_value = value.value
  local multiplier = device:get_field(constants.SIMPLE_METERING_MULTIPLIER_KEY) or 1
  local divisor = device:get_field(constants.SIMPLE_METERING_DIVISOR_KEY) or 1
  raw_value = raw_value * multiplier/divisor
  if device.preferences.logDebugPrint == true then
    print("SIMPLE_METERING_DIVISOR_KEY >>>>", device:get_field(constants.SIMPLE_METERING_DIVISOR_KEY))
    print("ELECTRICAL_MEASUREMENT_DIVISOR_KEY >>>>>", device:get_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY))
  end
  local offset = device:get_field(constants.ENERGY_METER_OFFSET) or 0
  if raw_value < offset then
    --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
    offset = 0
    device:set_field(constants.ENERGY_METER_OFFSET, offset, {persist = true})
  end
  raw_value = raw_value - offset
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.energyMeter.energy({value = raw_value, unit = "kWh" }))

  --- power_consumption_report calculation
  local delta_energy = 0.0
  raw_value = raw_value * 1000 -- need energy in Wh units
  local current_power_consumption = device:get_latest_state("main", capabilities.powerConsumptionReport.ID,
    capabilities.powerConsumptionReport.powerConsumption.NAME)
  if current_power_consumption ~= nil then
    delta_energy = math.max(raw_value - current_power_consumption.energy, 0.0)
  end
  device:emit_event(capabilities.powerConsumptionReport.powerConsumption({ energy = raw_value, deltaEnergy = delta_energy })) -- the unit of these values should be 'Wh'
end

--- active_power_meter_handler
local function active_power_meter_handler(driver, device, value, zb_rx)
  print(">>>> Active Power handler")
  local raw_value = value.value
  -- By default emit raw value
  local multiplier = device:get_field(constants.ELECTRICAL_MEASUREMENT_MULTIPLIER_KEY) or 1
  local divisor = device:get_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY) or 1

  if divisor == 0 then 
    --log.warn("Temperature scale divisor is 0; using 1 to avoid division by zero")
    divisor = 1
  end
  
  if device.preferences.logDebugPrint == true then
    print("multiplier >>>>",multiplier)
    print("divisor >>>>>",divisor)
  end
  raw_value = raw_value * multiplier/divisor

  local raw_value_watts = raw_value
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.powerMeter.power({value = raw_value_watts, unit = "W" }))
end

----- resetEnergyMeter_handler
local function resetEnergyMeter_handler(self, device, command)
  print("resetEnergyMeter_handler >>>>>>>", command.command)
  -- reset energy
  if device:get_manufacturer() == "_TZ3000_zloso4jk" then
    print("<<< Write reset currentSumatotry attribute >>>")
    local value_send = 0
    local data_value = {value = value_send, ID = 0x25} --data type Uint48
    local cluster_id = {value = 0x0702}
    local attr_id = 0x0000
    write.write_attribute_function(device, cluster_id, attr_id, data_value)
  end
  local _,last_reading = device:get_latest_state(command.component, capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME, 0, {value = 0, unit = "kWh"})
  if last_reading.value ~= 0 then
    local offset = device:get_field(constants.ENERGY_METER_OFFSET) or 0
    device:set_field(constants.ENERGY_METER_OFFSET, last_reading.value+offset, {persist = true})
  end
  device:emit_component_event({id = command.component}, capabilities.energyMeter.energy({value = 0.0, unit = "kWh"}))
  device:emit_event(capabilities.powerConsumptionReport.powerConsumption({ energy = 0.0, deltaEnergy = 0.0 })) -- the unit of these values should be 'Wh'
end

 ----- Groups_handler
 local function Groups_handler(driver, device, value, zb_rx)

  local zb_message = value
  local group_list = zb_message.body.zcl_body.group_list_list
  --Print table group_lists with function utils.stringify_table(group_list)
  if device.preferences.logDebugPrint == true then
    print("group_list >>>>>>",utils.stringify_table(group_list))
  end
  local group_Names =""
  for i, value in pairs(group_list) do
    if device.preferences.logDebugPrint == true then
      print("Message >>>>>>>>>>>",group_list[i].value)
    end
    group_Names = group_Names..tostring(group_list[i].value).."-"

  end
  --local text_Groups = "Groups Added: "..group_Names
  local text_Groups = group_Names
  if text_Groups == "" then text_Groups = "All Deleted" end
  --print (text_Groups)
  device:emit_event(get_Groups.getGroups(text_Groups))
end

----- delete_all_groups_handler
local function delete_all_groups_handler(self, device, command)
  device:send(Groups.server.commands.RemoveAllGroups(device, {}))
  device:send(Groups.server.commands.GetGroupMembership(device, {}))
end

-----driver_switched
local function driver_switched(self,device)
  print("<<< driver-Switched >>>")
  device.thread:call_with_delay(4, function() do_configure(self,device) end)
end

--- emit event to Global Command
local function default_response_handler(driver, device, zb_rx)
  print("<<< GlobalCommand Handler >>>")
  local status = zb_rx.body.zcl_body.status.value
  local cmd = zb_rx.body.zcl_body.cmd.value

  if status == Status.SUCCESS then
    --local cmd = zb_rx.body.zcl_body.cmd.value
    local event = nil

    if cmd == zcl_clusters.OnOff.server.commands.On.ID then
      event = capabilities.switch.switch.on()
    elseif cmd == zcl_clusters.OnOff.server.commands.Off.ID then
      event = capabilities.switch.switch.off()

      -- read power due to residual power < 5w can appears in app after power off
      if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
        set_status_timer = device:get_field("read-power")
        if set_status_timer then
          device.thread:cancel_timer(set_status_timer)
          device:set_field("read-power", nil)
        end
        local power_read = function(d)
          device:send_to_component("main", zcl_clusters.ElectricalMeasurement.attributes.ActivePower:read(device))
          device:send_to_component("main", zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:read(device))
        end
        set_status_timer = device.thread:call_with_delay(5, power_read, "power-energy delayed read")
        device:set_field("read-power", set_status_timer)
      end
    end

    if event ~= nil then
      device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)
    end
  end

  local visible_satate = false
  if device.preferences.signalMetricsVisibles == "Yes" then
    visible_satate = true
  end
  local gmt = os.date("%Y/%m/%d Time: %H:%M",os.time())
  local dni = string.format("0x%04X", zb_rx.address_header.src_addr.value)
  local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
  metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
  device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))

  -- -- read attribute power & enrgy 
  if device.preferences.powerEnergyRead ~= nil and cmd == zcl_clusters.OnOff.server.commands.On.ID then
  --if device:get_manufacturer() == "_TZ3000_9vo5icau" or 
   --device:get_manufacturer() == "_TZ3000_1h2x4akh" or
   --device:get_manufacturer() == "lumi.plug.mmeu01" or
   ---device:get_manufacturer() == "_TZ3000_gvn91tmx" or
   --device:get_manufacturer() == "_TZ3000_okaz9tjs" or
   --device:get_manufacturer() == "_TZ3000_g5xawfcq" then

    if device.preferences.logDebugPrint == true then 
      print("<<<<< Cancel read timers >>>>>")
    end
    set_status_timer = device:get_field("read-power")
    if set_status_timer then
      device.thread:cancel_timer(set_status_timer)
      device:set_field("read-power", nil)
    end
    set_status_timer = device:get_field("read-on-off")
    if set_status_timer then
      device.thread:cancel_timer(set_status_timer)
      device:set_field("read-on-off", nil)
    end

    local power_read = function(d)
      device:send_to_component("main", zcl_clusters.ElectricalMeasurement.attributes.ActivePower:read(device))
      device:send_to_component("main", zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:read(device))
    end
    set_status_timer = device.thread:call_with_delay(5, power_read, "power-energy delayed read")
    device:set_field("read-power", set_status_timer)

    local on_off_read = function(d)
      device:send_to_component("main", zcl_clusters.OnOff.attributes.OnOff:read(device))
    end
    local delay = device.preferences.powerEnergyRead
    if delay == nil then delay = 90 end
    set_status_timer = device.thread:call_with_delay(delay, on_off_read, "on_off_read delayed read")
    device:set_field("read-on-off", set_status_timer)
  end
end

---- On-Off Emit event
local function on_off_attr_handler(self, device, value, zb_rx)
  print("<<<<< Emit on_off >>>>>>")

  local visible_satate = false
  if device.preferences.signalMetricsVisibles == "Yes" then
    visible_satate = true
  end
  local gmt = os.date("%Y/%m/%d Time: %H:%M",os.time())
  local dni = string.format("0x%04X", zb_rx.address_header.src_addr.value)
  local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
  metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
  device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))

  local attr = capabilities.switch.switch
  --device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())
  local event = attr.on()
  if value.value == false or value.value == 0 then
    event = attr.off()

    -- read power due to residual power < 5w can appears in app after power off
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      set_status_timer = device:get_field("read-power")
      if set_status_timer then
        device.thread:cancel_timer(set_status_timer)
        device:set_field("read-power", nil)
      end
      local power_read = function(d)
        device:send_to_component("main", zcl_clusters.ElectricalMeasurement.attributes.ActivePower:read(device))
        device:send_to_component("main", zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:read(device))
      end
      set_status_timer = device.thread:call_with_delay(5, power_read, "power-energy delayed read")
      device:set_field("read-power", set_status_timer)
    end
  elseif value.value == true or value.value == 1 then

  -- -- read attribute power & enrgy
    if device.preferences.powerEnergyRead ~= nil then
    --if device:get_manufacturer() == "_TZ3000_9vo5icau" or 
      --device:get_manufacturer() == "_TZ3000_1h2x4akh" or
      --device:get_manufacturer() == "lumi.plug.mmeu01" or
      ---device:get_manufacturer() == "_TZ3000_gvn91tmx" or
      --device:get_manufacturer() == "_TZ3000_okaz9tjs" or
      --device:get_manufacturer() == "_TZ3000_g5xawfcq" then 

      if device.preferences.logDebugPrint == true then 
        print("<<<<< Cancel read timers >>>>>")
      end
      set_status_timer = device:get_field("read-power")
      if set_status_timer then
        device.thread:cancel_timer(set_status_timer)
        device:set_field("read-power", nil)
      end
      set_status_timer = device:get_field("read-on-off")
      if set_status_timer then
        device.thread:cancel_timer(set_status_timer)
        device:set_field("read-on-off", nil)     
      end

      local power_read = function(d)
        device:send_to_component("main", zcl_clusters.ElectricalMeasurement.attributes.ActivePower:read(device))
        device:send_to_component("main", zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:read(device))
      end
      set_status_timer = device.thread:call_with_delay(5, power_read, "power-energy delayed read")
      device:set_field("read-power", set_status_timer)
      
      local on_off_read = function(d)
        device:send_to_component("main", zcl_clusters.OnOff.attributes.OnOff:read(device))
      end
      local delay = device.preferences.powerEnergyRead
      if delay == nil then delay = 90 end
      set_status_timer = device.thread:call_with_delay(delay, on_off_read, "on_off_read delayed read")
      device:set_field("read-on-off", set_status_timer)
    end
  end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)
end

  -- custom config
  local function custom_configure(self, device)
    print("<<< custom configure >>>")
  end

 -- device_init
 local function device_init(self ,device)
    print("<<< device_init >>>")

     ------ Change profile & Icon
    if device.preferences.changeProfile == "Switch" then
      device:try_update_metadata({profile = "switch-power"})
    elseif device.preferences.changeProfile == "Plug" then
      device:try_update_metadata({profile = "switch-power-plug"})
    elseif device.preferences.changeProfile == "Light" then
      device:try_update_metadata({profile = "switch-power-light"})
    elseif device.preferences.changeProfileEner == "Switch" then
      device:try_update_metadata({profile = "switch-power-energy"})
    elseif device.preferences.changeProfileEner == "Plug" then
      device:try_update_metadata({profile = "switch-power-energy-plug"})
    elseif device.preferences.changeProfileEner == "Light" then
      device:try_update_metadata({profile = "switch-power-energy-light"})
    end

    -- due to error in profile asign in hub firmware
    if device:get_manufacturer() == "_TZ3000_9vo5icau" or 
      device:get_manufacturer() == "_TZ3000_1h2x4akh" or
      device:get_manufacturer() == "lumi.plug.mmeu01" or
      ---device:get_manufacturer() == "_TZ3000_gvn91tmx" or
      device:get_manufacturer() == "_TZ3000_okaz9tjs" or
      --device:get_manufacturer() == "_TZ3000_kdi2o9m6" or -- ONLY FOR MY TEST
      device:get_manufacturer() == "_TZ3000_g5xawfcq" then
        device:try_update_metadata({profile = "switch-power-energy-plug-refresh"})
    --elseif device:get_manufacturer() == "_TZ3000_kdi2o9m6" then -- for my test only
      --device:try_update_metadata({profile = "switch-power-energy-plug"})
    end

    random.do_init(self,device)

    device.thread:call_with_delay(4, function() do_configure(self,device) end)
 end

---- Driver template config
local zigbee_switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.switchLevel,
    capabilities.powerMeter,
    capabilities.energyMeter,
    random_On_Off,
    random_Next_Step,
    capabilities.refresh
  },
  lifecycle_handlers = {
    infoChanged = random.do_Preferences,
    init = device_init,
    --init = driver_switched,
    removed = random.do_removed,
    doConfigure = custom_configure,
    --doConfigure = do_configure,
    --driverSwitched = driver_switched,
  },
  capability_handlers = {
    [random_On_Off.ID] = {
      [random_On_Off.commands.setRandomOnOff.NAME] = random.random_on_off_handler,
    },
    [capabilities.energyMeter.ID] = {
      [capabilities.energyMeter.commands.resetEnergyMeter.NAME] = resetEnergyMeter_handler,
    },
    [get_Groups.ID] = {
      [get_Groups.commands.setGetGroups.NAME] = delete_all_groups_handler,
    }
  },
  zigbee_handlers = {
    global = {
      [zcl_clusters.OnOff.ID] = {
        [zcl_global_commands.DEFAULT_RESPONSE_ID] = default_response_handler
      }
    },
    cluster = {
      [zcl_clusters.Groups.ID] = {
        [zcl_clusters.Groups.commands.GetGroupMembershipResponse.ID] = Groups_handler
      },
    },
    attr = {
      [zcl_clusters.OnOff.ID] = {
        [zcl_clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
      },
      [zcl_clusters.SimpleMetering.ID] = {
        --[zcl_clusters.SimpleMetering.attributes.InstantaneousDemand.ID] = instantaneous_demand_handler,
        [zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered.ID] = energy_meter_handler
      },
      --[zcl_clusters.ElectricalMeasurement.ID] = {
        --[zcl_clusters.ElectricalMeasurement.attributes.ActivePower.ID] = active_power_meter_handler,
      --},
    },
  },
  sub_drivers = { require("device-temperature")},
}
-- run driver
defaults.register_for_default_handlers(zigbee_switch_driver_template, zigbee_switch_driver_template.supported_capabilities)
local zigbee_switch_power = ZigbeeDriver("Zigbee_Switch_power", zigbee_switch_driver_template)
zigbee_switch_power:run()