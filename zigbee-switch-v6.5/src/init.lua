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

--------- Author Mariano Colmenarejo (Oct 2021)

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local utils = require "st.utils"
local Groups = zcl_clusters.Groups


-- driver local modules load
local random = require "random"

--- Custom Capabilities
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local energy_Reset = capabilities["legendabsolute60149.energyReset1"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]
--local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

  ---- setEnergyReset_handler
local function setEnergyReset_handler(self,device,command)
  --print("command.args.value >>>>>", command.args.value)
  print(">>>> RESET Energy <<<<<")
  device:emit_event_for_endpoint("main", capabilities.energyMeter.energy({value = 0, unit = "kWh" }))
  local date_reset = "Last: ".. string.format("%.3f",device:get_field("energy_Total")).." kWh".." ".."("..os.date("%m/%d/%Y",os.time() + device.preferences.localTimeOffset * 3600)..")"
  device:set_field("date_reset", date_reset, {persist = false})
  device:emit_event(energy_Reset.energyReset(date_reset))
  device:set_field("energy_Total", 0, {persist = false})
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
  if text_Groups == "" then text_Groups = "DeleteAllGroups" end
  print (text_Groups)
  device:emit_event(get_Groups.getGroups(text_Groups))
end

----- delete_all_groups_handler
local function delete_all_groups_handler(self, device, command)
  device:send(Groups.server.commands.RemoveAllGroups(device, {}))
  device:send(Groups.server.commands.GetGroupMembership(device, {}))
end

--do_configure
local function do_configure(self, device)
  print("<< do Configure function >>")
   --- _TZ3000_9hpxg80k need special configure in init lifecycle, read attribute on-off every 120 sec and not configure reports
  if device:get_manufacturer() ~= "_TZ3000_9hpxg80k" then
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
    --device:remove_monitored_attribute(0x0006, 0x0000)
  end
end

------ do_configure device when driver switched
local function driver_Switched(self,device)
   ------ Change profile & Icon
   if device.preferences.changeProfile == "Switch" then
    device:try_update_metadata({profile = "single-switch"})
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
   end 
  device:refresh()

   --- _TZ3000_9hpxg80k need special configure in init lifecycle, read attribute on-off every 120 sec and not configure reports
  if device:get_manufacturer() ~= "_TZ3000_9hpxg80k" then
    -- Configure OnOff interval report
    device.thread:call_with_delay(3, function(d) --23/12/23
      device:configure()
      print("doConfigure performed, transitioning device to PROVISIONED")
      device:try_update_metadata({ provisioning_state = "PROVISIONED" })
    end, "configure")
  end
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
  local function lazy_load_if_possible(sub_driver_name)
    -- gets the current lua libs api version
    local version = require "version"
  
    --print("<<<<< Library Version:", version.api)
    -- version 9 will include the lazy loading functions
    if version.api >= 9 then
      return ZigbeeDriver.lazy_load_sub_driver(require(sub_driver_name))
    else
      return require(sub_driver_name)
    end
  end

---- Driver template config
local zigbee_switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    random_On_Off,
    random_Next_Step,
    capabilities.battery,
    capabilities.refresh
  },
  lifecycle_handlers = {
    infoChanged = random.do_Preferences,
    init = random.do_init,
    removed = random.do_removed,
    driverSwitched = driver_Switched,
    doConfigure = do_configure
  },
  capability_handlers = {
    [energy_Reset.ID] = {
      [energy_Reset.commands.setEnergyReset.NAME] = setEnergyReset_handler,
    },
    [capabilities.energyMeter.ID] = {
      [capabilities.energyMeter.commands.resetEnergyMeter.NAME] = setEnergyReset_handler,
    },
    [random_On_Off.ID] = {
      [random_On_Off.commands.setRandomOnOff.NAME] = random.random_on_off_handler,
    },
    [get_Groups.ID] = {
      [get_Groups.commands.setGetGroups.NAME] = delete_all_groups_handler,
    }
  },
  zigbee_handlers = {
    cluster = {
      [zcl_clusters.Groups.ID] = {
        [zcl_clusters.Groups.commands.GetGroupMembershipResponse.ID] = Groups_handler
      }
    },
    attr = {
      [zcl_clusters.OnOff.ID] = {
      [zcl_clusters.OnOff.attributes.OnOff.ID] = random.on_off_attr_handler
    }
  },
 },
 sub_drivers = { 
  lazy_load_if_possible("tuya-fingerbot"),
  lazy_load_if_possible("tuya-MHCOZY")
},
 --health_check = false
}
-- run driver
defaults.register_for_default_handlers(zigbee_switch_driver_template, zigbee_switch_driver_template.supported_capabilities, {native_capability_cmds_enabled = true})
--defaults.register_for_default_handlers(zigbee_switch_driver_template, zigbee_switch_driver_template.supported_capabilities)
local zigbee_switch = ZigbeeDriver("Zigbee_Switch_Mc", zigbee_switch_driver_template)
zigbee_switch:run()