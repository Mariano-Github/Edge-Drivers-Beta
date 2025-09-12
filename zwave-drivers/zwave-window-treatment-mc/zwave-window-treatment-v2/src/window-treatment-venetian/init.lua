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

local cc = (require "st.zwave.CommandClass")
local Configuration = (require "st.zwave.CommandClass.Configuration")({version=1})
local Basic = (require "st.zwave.CommandClass.Basic")({ version=1 })
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({version=3})

local WindowShadeDefaults = require "st.zwave.defaults.windowShade"
local WindowShadeLevelDefaults = require "st.zwave.defaults.windowShadeLevel"
--- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({version=3})

local WINDOW_TREATMENT_VENETIAN_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x1D01, model = 0x1000}, -- Fibaro Walli Roller Shutter
  --{mfr = 0x010F, prod = 0x0302, model = 0x1000}, -- Fibaro Roller Shutter 2
  {mfr = 0x010F, prod = 0x0303, model = 0x1000}, -- Fibaro Roller Shutter 3
  {mfr = 0x010F, prod = 0x0303, model = 0x2000}, -- Fibaro Roller shutter_3 US version
  {mfr = 0x010F, prod = 0x0303, model = 0x3000}, -- Fibaro Roller shutter_3 AU version
  {mfr = 0x0159, prod = 0x0003, model = 0x0052}, -- Qubino Flush Shutter AC
  {mfr = 0x0159, prod = 0x0003, model = 0x0053}, -- Qubino Flush Shutter DC
  {mfr = 0x010F, prod = 0x0301, model = 0x1001}, -- Fibaro Roller Shutter 2 FGRM-222
  {mfr = 0x010F, prod = 0x0302, model = 0x1000}, -- Fibaro Roller Shutter 2 FGR-222
  {mfr = 0x010F, prod = 0x0300, model = 0x100A}, -- Fibaro Roller Shutter 1 FGR-221
  {mfr = 0x010F, prod = 0x0304, model = 0x1000}, -- Fibaro Roller shutter_4 EU version
  --{mfr = 0x010F, prod = 0x0304, model = 0x2000}, -- Fibaro Roller shutter_4 US version
  --{mfr = 0x010F, prod = 0x0304, model = 0x3000}, -- Fibaro Roller shutter_4 AU version
}

local function can_handle_window_treatment_venetian(opts, driver, device, ...)
  for _, fingerprint in ipairs(WINDOW_TREATMENT_VENETIAN_FINGERPRINTS) do
    if device:id_match( fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("window-treatment-venetian")
      return true, subdriver
    end
  end
  return false
end

local function shade_event_handler(self, device, cmd)
  WindowShadeDefaults.zwave_handlers[cc.SWITCH_MULTILEVEL][SwitchMultilevel.REPORT](self, device, cmd)
  WindowShadeLevelDefaults.zwave_handlers[cc.SWITCH_MULTILEVEL][SwitchMultilevel.REPORT](self, device, cmd)

  -- referesh level and status
  if device.zwave_manufacturer_id == 0x010F and (device.zwave_product_type == 0x0302 or device.zwave_product_type == 0x0301) then -- Fibaro Roller Shutter FGR-222
    --print("<<< level_target >>>",device:get_field("level_target"))
    if device:get_field("level_target") ~= nil then
      local level = cmd.args.value and cmd.args.value or cmd.args.target_value
      level = device.preferences.reverse and 99 - level or level
      --print("<<< Level >>>", level)
      for timer in pairs(device.thread.timers) do
        --print("<<<<< Cancel all timer >>>>>")
        device.thread:cancel_timer(timer)
      end
      local query_device = function()
        device:send_to_component(SwitchMultilevel:Get({}), cmd.component)
        --device:send(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS},{dst_channels = {cmd.src_channel}}))
        --device:send(Meter:Get({scale = Meter.scale.electric_meter.WATTS},{dst_channels = {cmd.src_channel}}))
      end
      device.thread:call_with_delay(4, query_device)
      if device:get_field("level_target") == level then
        device:set_field("level_target", nil, {persist = false})
        local query_device_power = function()
          device:send(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS},{dst_channels = {cmd.src_channel}}))
          device:send(Meter:Get({scale = Meter.scale.electric_meter.WATTS},{dst_channels = {cmd.src_channel}}))
        end
        device.thread:call_with_delay(6, query_device_power)
      end
    end
  end
end

local function endpoint_to_component(device, endpoint)
  if endpoint == 2 then
    return "venetianBlind"
  else
    return "main"
  end
end

local function component_to_endpoint(device, component)
  if component == "venetianBlind" then
    return {2}
  else
    return {}
  end
end

local function map_components(self, device)
  device:set_endpoint_to_component_fn(endpoint_to_component)
  device:set_component_to_endpoint_fn(component_to_endpoint)
end

local window_treatment_venetian = {
  NAME = "window treatment venetian",
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.REPORT] = shade_event_handler
    },
    [cc.SWITCH_MULTILEVEL] = {
      [SwitchMultilevel.REPORT] = shade_event_handler
    }
  },
  can_handle = can_handle_window_treatment_venetian,
  lifecycle_handlers = {
    init = map_components
  },
  sub_drivers = {
    require("window-treatment-venetian/fibaro-roller-shutter"),
    require("window-treatment-venetian/fibaro-roller-shutter-2"),
    require("window-treatment-venetian/fibaro-roller-shutter-3"),
    require("window-treatment-venetian/fibaro-roller-shutter-4"),
    require("window-treatment-venetian/qubino-flush-shutter")
  }
}

return window_treatment_venetian
