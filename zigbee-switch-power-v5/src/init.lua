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
--local zigbee_constants = require "st.zigbee.constants"
local ElectricalMeasurement = zcl_clusters.ElectricalMeasurement
local SimpleMetering = zcl_clusters.SimpleMetering
local utils = require "st.utils"
local Groups = zcl_clusters.Groups
local constants = require "st.zigbee.constants"
local device_management = require "st.zigbee.device_management"
local Status = require "st.zigbee.generated.types.ZclStatus"
local zcl_global_commands = require "st.zigbee.zcl.global_commands"

-- driver local modules load
local random = require "random"
local write = require "writeAttribute"

--- Custom Capabilities
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

local do_configure = function(self, device)

  --- save optionals device divisors

  if device:get_manufacturer() == "sengled" then
    local power_divisor = 10
    local energy_divisor = 10000
    device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, power_divisor, {persist = true})
    device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, energy_divisor, {persist = true})
  elseif device:get_model() == "TS011F" then
    if (device:get_manufacturer() == "_TZ3000_gjnozsaz" or
      device:get_manufacturer() == "_TZ3000_gvn91tmx" or
      device:get_manufacturer() == "_TZ3000_qeuvnohg" or
      device:get_manufacturer() == "_TZ3000_amdymr71" or
      device:get_manufacturer() == "_TZ3000_typdpbpg" or
      device:get_manufacturer() == "_TZ3000_ynmowqk2" or
      device:get_manufacturer() == "_TZ3000_cphmq0q7") then
        device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, 100, {persist = true})
    end
  end
  
  if device:get_manufacturer() == "_TZ3000_9vo5icau" or 
   device:get_manufacturer() == "_TZ3000_1h2x4akh" or 
   device:get_manufacturer() == "_TZ3000_g5xawfcq" then 
    --and device:get_model() == "TS011F"
    -- power and energy configure reporting
    device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, self.environment_info.hub_zigbee_eui))
    device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 300)) --0, 120
    device:send(device_management.build_bind_request(device, zcl_clusters.ElectricalMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(zcl_clusters.ElectricalMeasurement.attributes.ActivePower:configure_reporting(device, 1, 3600, 5))
    device:send(device_management.build_bind_request(device, zcl_clusters.SimpleMetering.ID, self.environment_info.hub_zigbee_eui))
    device:send(zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:configure_reporting(device, 5, 3600, 1))

  else
    device:configure()
    -- Additional one time configuration
    if device:supports_capability(capabilities.energyMeter) or device:supports_capability(capabilities.powerMeter) then
      -- Divisor and multipler for EnergyMeter
      device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
      device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
      -- Divisor and multipler for PowerMeter
      device:send(SimpleMetering.attributes.Divisor:read(device))
      device:send(SimpleMetering.attributes.Multiplier:read(device))
    end
  end
  random.do_init(self,device)
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
  
  print("multiplier >>>>",multiplier)
  print("divisor >>>>>",divisor)
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
  local offset = device:get_field(constants.ENERGY_METER_OFFSET) or 0
  if raw_value < offset then
    --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
    offset = 0
    device:set_field(constants.ENERGY_METER_OFFSET, offset, {persist = true})
  end
  raw_value = raw_value - offset
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.energyMeter.energy({value = raw_value, unit = "kWh" }))
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
  
  print("multiplier >>>>",multiplier)
  print("divisor >>>>>",divisor)
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
end

 ----- Groups_handler
 local function Groups_handler(driver, device, value, zb_rx)

  local zb_message = value
  local group_list = zb_message.body.zcl_body.group_list_list
  --Print table group_lists with function utils.stringify_table(group_list)
  print("group_list >>>>>>",utils.stringify_table(group_list))
  
  local group_Names =""
  for i, value in pairs(group_list) do
    print("Message >>>>>>>>>>>",group_list[i].value)
    group_Names = group_Names..tostring(group_list[i].value).."-"
  end
  --local text_Groups = "Groups Added: "..group_Names
  local text_Groups = group_Names
  if text_Groups == "" then text_Groups = "All Deleted" end
  print (text_Groups)
  device:emit_event(get_Groups.getGroups(text_Groups))
end

----- delete_all_groups_handler
local function delete_all_groups_handler(self, device, command)
  device:send(Groups.server.commands.RemoveAllGroups(device, {}))
  device:send(Groups.server.commands.GetGroupMembership(device, {}))
end

-----driver_switched
local function driver_switched(self,device)
  device.thread:call_with_delay(5, function() do_configure(self,device) end)
end

--- emit event to Global Command
local function default_response_handler(driver, device, zb_rx)
  print("<<< GlobalCommand Handler >>>")
  local status = zb_rx.body.zcl_body.status.value

  if status == Status.SUCCESS then
    local cmd = zb_rx.body.zcl_body.cmd.value
    local event = nil

    if cmd == zcl_clusters.OnOff.server.commands.On.ID then
      event = capabilities.switch.switch.on()
    elseif cmd == zcl_clusters.OnOff.server.commands.Off.ID then
      event = capabilities.switch.switch.off()
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
  --local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. <b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
  local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
  metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
  device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))

  -- -- read attribute power & enrgy 
  if device:get_manufacturer() == "_TZ3000_9vo5icau" or 
   device:get_manufacturer() == "_TZ3000_1h2x4akh" or
   device:get_manufacturer() == "_TZ3000_g5xawfcq" then
   --and device:get_model() == "TS011F" then

    local power_read = function(d)
      device:send_to_component("main", zcl_clusters.ElectricalMeasurement.attributes.ActivePower:read(device))
      device:send_to_component("main", zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:read(device))
    end
      device.thread:call_with_delay(5, power_read, "power-energy delayed read")

      local on_off_read = function(d)
        device:send_to_component("main", zcl_clusters.OnOff.attributes.OnOff:read(device))
      end
        device.thread:call_with_delay(90, on_off_read, "on_off_read delayed read")
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
  --local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. <b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
  local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
  metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
  device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))

  local attr = capabilities.switch.switch
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())
  
  -- -- read attribute power & enrgy 
  if device:get_manufacturer() == "_TZ3000_9vo5icau" or 
    device:get_manufacturer() == "_TZ3000_1h2x4akh" or
    device:get_manufacturer() == "_TZ3000_g5xawfcq" then 
    --and device:get_model() == "TS011F" then

    local power_read = function(d)
      device:send_to_component("main", zcl_clusters.ElectricalMeasurement.attributes.ActivePower:read(device))
      device:send_to_component("main", zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered:read(device))
    end
      device.thread:call_with_delay(5, power_read, "power-energy delayed read")
    
      local on_off_read = function(d)
        device:send_to_component("main", zcl_clusters.OnOff.attributes.OnOff:read(device))
      end
        device.thread:call_with_delay(90, on_off_read, "on_off_read delayed read")  
    end

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
    init = do_configure,
    removed = random.do_removed,
    --doConfigure = do_configure,
    driverSwitched = driver_switched
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
      --[zcl_clusters.SimpleMetering.ID] = {
        --[zcl_clusters.SimpleMetering.attributes.InstantaneousDemand.ID] = instantaneous_demand_handler
      --},
      --[zcl_clusters.SimpleMetering.ID] = {
        --[zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered.ID] = energy_meter_handler
      --},
      --[zcl_clusters.ElectricalMeasurement.ID] = {
        --[zcl_clusters.ElectricalMeasurement.attributes.ActivePower.ID] = active_power_meter_handler,
      --},
    },
  }  
}
-- run driver
defaults.register_for_default_handlers(zigbee_switch_driver_template, zigbee_switch_driver_template.supported_capabilities)
local zigbee_switch = ZigbeeDriver("Zigbee_Switch", zigbee_switch_driver_template)
zigbee_switch:run()
