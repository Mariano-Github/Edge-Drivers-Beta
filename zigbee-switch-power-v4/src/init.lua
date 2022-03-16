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
local zigbee_constants = require "st.zigbee.constants"
local ElectricalMeasurement = zcl_clusters.ElectricalMeasurement
local SimpleMetering = zcl_clusters.SimpleMetering
local utils = require "st.utils"
local Groups = zcl_clusters.Groups
local constants = require "st.zigbee.constants"


-- driver local modules load
local random = require "random"

--- Custom Capabilities
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]

local do_configure = function(self, device)

  --- save device divisors
  --local power_divisor = 100
  --local energy_divisor = 1
  if device:get_manufacturer() == "sengled" then
   local power_divisor = 10
   local energy_divisor = 10000
  --end
   device:set_field(zigbee_constants.SIMPLE_METERING_DIVISOR_KEY, power_divisor, {persist = true})
   device:set_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, energy_divisor, {persist = true})  
  end
  
  --device:refresh()
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

  local raw_value_watts = raw_value
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
    cluster = {
      [zcl_clusters.Groups.ID] = {
        [zcl_clusters.Groups.commands.GetGroupMembershipResponse.ID] = Groups_handler
      },
    },
    attr = {
      [zcl_clusters.SimpleMetering.ID] = {
        [zcl_clusters.SimpleMetering.attributes.InstantaneousDemand.ID] = instantaneous_demand_handler
      },
      --[zcl_clusters.SimpleMetering.ID] = {
        --[zcl_clusters.SimpleMetering.attributes.CurrentSummationDelivered.ID] = energy_meter_handler
      --},
      [zcl_clusters.ElectricalMeasurement.ID] = {
        [zcl_clusters.ElectricalMeasurement.attributes.ActivePower.ID] = active_power_meter_handler,
      },
    },
  }  
}
-- run driver
defaults.register_for_default_handlers(zigbee_switch_driver_template, zigbee_switch_driver_template.supported_capabilities)
local zigbee_switch = ZigbeeDriver("Zigbee_Switch", zigbee_switch_driver_template)
zigbee_switch:run()