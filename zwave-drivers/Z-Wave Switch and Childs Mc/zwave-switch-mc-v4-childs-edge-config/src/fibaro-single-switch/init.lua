-- Copyright 2022 SmartThings
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

--local ButtonDefaults = require "st.zwave.defaults.button"
local EnergyMeterDefaults = require "st.zwave.defaults.energyMeter"
local PowerMeterDefaults = require "st.zwave.defaults.powerMeter"
local SwitchDefaults = require "st.zwave.defaults.switch"
local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.CentralScene
local CentralScene = (require "st.zwave.CommandClass.CentralScene")({ version=1 })
--- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({ version=3 })
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({ version = 2 })

local FIBARO_SINGLE_SWITCH_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0403, model = 0x1000}, -- Fibaro Switch FGS-213
  {mfr = 0x010F, prod = 0x0403, model = 0x2000}, -- Fibaro Switch FGS-213
  {mfr = 0x010F, prod = 0x0403, model = 0x3000}, -- Fibaro Switch FGS-213
  {mfr = 0x010F, prod = 0x0404, model = 0x1000}, -- Fibaro Smart relay single FGS-214
  {mfr = 0x010F, prod = 0x0404, model = 0x2000}, -- Fibaro Smart relay single FGS-214
  {mfr = 0x010F, prod = 0x0404, model = 0x3000}, -- Fibaro Smart relay single FGS-214
}

local function can_handle_fibaro_single_switch(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(FIBARO_SINGLE_SWITCH_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("fibaro-single-switch")
      return true, subdriver
    end
  end
  return false
end

local function central_scene_notification_handler(self, device, cmd)
  local map_key_attribute_to_capability = {
    [CentralScene.key_attributes.KEY_PRESSED_1_TIME] = capabilities.button.button.pushed,
    [CentralScene.key_attributes.KEY_RELEASED] = capabilities.button.button.held,
    [CentralScene.key_attributes.KEY_HELD_DOWN] = capabilities.button.button.down_hold,
    [CentralScene.key_attributes.KEY_PRESSED_2_TIMES] = capabilities.button.button.double,
    [CentralScene.key_attributes.KEY_PRESSED_3_TIMES] = capabilities.button.button.pushed_3x
  }

  local event = map_key_attribute_to_capability[cmd.args.key_attributes]
  local button_number = cmd.args.scene_number

  local component = device.profile.components["button" .. button_number]

  if component ~= nil then
    device:emit_component_event(component, event({state_change = true}))
  end
end

local function meter_report_handler(self, device, cmd)
  if cmd.src_channel ~= 2 then
    if cmd.args.scale == Meter.scale.electric_meter.KILOWATT_HOURS then
      EnergyMeterDefaults.zwave_handlers[cc.METER][Meter.REPORT](self, device, cmd)
    elseif cmd.args.scale == Meter.scale.electric_meter.WATTS then
      PowerMeterDefaults.zwave_handlers[cc.METER][Meter.REPORT](self, device, cmd)
    end
  end
end

local function switch_binary_report_handler(self, device, cmd)
  if cmd.src_channel ~= 2 then
    SwitchDefaults.zwave_handlers[cc.SWITCH_BINARY][SwitchBinary.REPORT](self, device, cmd)
  end
end

local fibaro_single_switch = {
  NAME = "fibaro single switch",
  zwave_handlers = {
    [cc.CENTRAL_SCENE] = {
      [CentralScene.NOTIFICATION] = central_scene_notification_handler
    },
    [cc.METER] = {
      [Meter.REPORT] = meter_report_handler
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = switch_binary_report_handler
    }
  },
  can_handle = can_handle_fibaro_single_switch,
}

return fibaro_single_switch
