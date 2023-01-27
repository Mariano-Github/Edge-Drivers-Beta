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
local OnOff = zcl_clusters.OnOff
local utils = require "st.utils"
local Groups = zcl_clusters.Groups


-- driver local modules load
local random = require "random"

--- Custom Capabilities
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local energy_Reset = capabilities["legendabsolute60149.energyReset1"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

  ---- setEnergyReset_handler
local function setEnergyReset_handler(self,device,command)
  print("command.args.value >>>>>", command.args.value)
  --device:emit_event(energy_Reset.energyReset(command.args.value))
  if command.args.value == "No Reset" then
    device:emit_event(energy_Reset.energyReset(device:get_field("date_reset")))

  else
   print(">>>> RESET Energy <<<<<")
   --device:set_field("energy_Total", 0, {persist = true})
   device:emit_event_for_endpoint("main", capabilities.energyMeter.energy({value = 0, unit = "kWh" }))
   local date_reset = "Last: ".. string.format("%.3f",device:get_field("energy_Total")).." kWh".." ".."("..os.date("%m/%d/%Y")..")"
   device:set_field("date_reset", date_reset, {persist = true})
   --device:emit_event(energy_Reset.energyReset(command.args.value))
   device:emit_event(energy_Reset.energyReset(date_reset))
   device:set_field("energy_Total", 0, {persist = false})
  end
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

--do_configure
local function do_configure(self, device)
  if device:get_manufacturer() ~= "_TZ3000_9hpxg80k" then
    device:configure()
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
  if device:get_manufacturer() ~= "_TZ3000_9hpxg80k" then
    device:configure()
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
 }
}
-- run driver
defaults.register_for_default_handlers(zigbee_switch_driver_template, zigbee_switch_driver_template.supported_capabilities)
local zigbee_switch = ZigbeeDriver("Zigbee_Switch", zigbee_switch_driver_template)
zigbee_switch:run()