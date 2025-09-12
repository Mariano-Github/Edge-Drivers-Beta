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

--- @type st.zwave.CommandClass
local cc = (require "st.zwave.CommandClass")
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({version=1})
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=1})
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({ version = 1 })
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({version=4})
--- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({version=3})
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })
local capabilities = require "st.capabilities"

local window_Shade_Preset_Value = capabilities ["legendabsolute60149.windowShadePresetValue"]
local PRESET_LEVEL = 50

local FIBARO_ROLLER_SHUTTER_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0301, model = 0x1001}, -- Fibaro Roller Shutter 2 FGRM-222
  {mfr = 0x010F, prod = 0x0302, model = 0x1000}, -- Fibaro Roller Shutter 2 FGR-222
  {mfr = 0x010F, prod = 0x0300, model = 0x100A}, -- Fibaro Roller Shutter 1 FGR-221
}

-- configuration parameters
local CALIBRATION_CONFIGURATION = 29
local OPERATING_MODE_CONFIGURATION = 10

-- fieldnames
local CALIBRATION = "calibration"
local OPERATING_MODE = "operating_mode"

-- calibration statuses
local CLB_NOT_STARTED = "not_started"
local CLB_DONE = "done"
local CLB_PENDING = "pending"

local function can_handle_fibaro_roller_shutter_2(opts, driver, device, ...)
  for _, fingerprint in ipairs(FIBARO_ROLLER_SHUTTER_FINGERPRINTS) do
    if device:id_match( fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return true
    end
  end
  return false
end

local function configuration_report(driver, device, cmd)

  if device.zwave_product_type == 0x0300 then return end -- Fibaro Roller Shutter 1 FGR-221 

  local parameter_number = cmd.args.parameter_number
  local configuration_value = cmd.args.configuration_value

  if parameter_number == CALIBRATION_CONFIGURATION then 
    local calibration_status
    if configuration_value == 0 then
      calibration_status = CLB_DONE
    elseif configuration_value == 1 then
      if device:get_field(CALIBRATION) == CLB_NOT_STARTED then
        calibration_status = CLB_PENDING
      end
    end
    device:set_field(CALIBRATION, calibration_status, {persist = true})
  end
end

local function device_added(self, device)
  if device:get_field("windowShadePreset_Value") == nil then 
    device:set_field("windowShadePreset_Value", "50%", {persist = true})
  end
  device:emit_event(window_Shade_Preset_Value.windowShadePresetValue(device:get_field("windowShadePreset_Value")))
  
  if device.zwave_product_type == 0x0300 then -- Fibaro Roller Shutter 1 FGR-221
    device:send(Association:Set({grouping_identifier = 3, node_ids = {self.environment_info.hub_zwave_id}}))
  else
    device:send(Association:Set({grouping_identifier = 3, node_ids = {self.environment_info.hub_zwave_id}}))
    device:set_field(CALIBRATION, CLB_NOT_STARTED)
  end
  device:do_refresh()
end

---switch_binary_report_handler for switch physical change
local function switch_binary_report_handler(driver, device, cmd)
  print("cmd.args.switch_value >>>>>>>>>>>>>",cmd.args.switch_value)
  local cmd_value = device.preferences.reverse and 255 - cmd.args.switch_value or cmd.args.switch_value
  --if cmd.args.switch_value == 255  then
  if cmd_value == 255  then
    --device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShade.windowShade.open())
    -- save level traget to read final shade level
    device:set_field("level_target", 99, {persist = false})
    --device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShadeLevel.shadeLevel(100))
  elseif cmd_value == 0  then
    --device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShade.windowShade.closed())
    -- save level traget to read final shade level
    device:set_field("level_target", 0, {persist = false})
    --device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShadeLevel.shadeLevel(0))
  else
    device:set_field("level_target", nil, {persist = false})
  end
  device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShade.windowShade.partially_open())

  local query_device = function()
   device:send(SwitchMultilevel:Get({},{dst_channels = {cmd.src_channel}}))
   --device:send(Basic:Get({},{dst_channels = {cmd.src_channel}}))
   if device.zwave_product_type ~= 0x0300 then -- Fibaro Roller Shutter 1 FGR-221
    device:send(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS},{dst_channels = {cmd.src_channel}}))
    device:send(Meter:Get({scale = Meter.scale.electric_meter.WATTS},{dst_channels = {cmd.src_channel}}))
   end
  end
  device.thread:call_with_delay(constants.MIN_DIMMING_GET_STATUS_DELAY, query_device)

end

local function meter_report_handler(self, device, cmd)
  print("<<< meter handler >>>")
  local event_arguments = nil
  if cmd.args.scale == Meter.scale.electric_meter.WATTS then
    event_arguments = {
      value = cmd.args.meter_value,
      unit = "W"
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.powerMeter.power(event_arguments)
    )
  else
    if cmd.args.scale == Meter.scale.electric_meter.KILOWATT_HOURS then
      event_arguments = {
        value = cmd.args.meter_value,
        unit = "kWh"
      }
    elseif cmd.args.scale == Meter.scale.electric_meter.KILOVOLT_AMPERE_HOURS then
      event_arguments = {
        value = cmd.args.meter_value,
        unit = "kVAh"
      }
    end
    if event_arguments ~= nil then
      device:emit_event_for_endpoint(
        cmd.src_channel,
        capabilities.energyMeter.energy(event_arguments)
      )
    end
  end

  -- referesh level and status
  if device.zwave_product_type ~= 0x0300 then -- Fibaro Roller Shutter 1 FGR-221
    local query_device = function()
      device:send_to_component(Basic:Get({}), cmd.component)
      device:send_to_component(SwitchMultilevel:Get({}), cmd.component)
    end
    device.thread:call_with_delay(1, query_device)
  end
end

local function window_shade_level_change(self, device, level, command)
  local set
  local get

  level = device.preferences.reverse and 99 - level or level
  -- save level traget to read final shade level
  device:set_field("level_target", level, {persist = false})

  if device:is_cc_supported(cc.SWITCH_MULTILEVEL) then
    set = SwitchMultilevel:Set({
      value = level,
      duration = constants.DEFAULT_DIMMING_DURATION
    })
    get = SwitchMultilevel:Get({})
  else
    set = Basic:Set({
      value = level
    })
    get = Basic:Get({})
  end
  device:send_to_component(set, command.component)
  local query_device = function()
    device:send_to_component(get, command.component)
    device:send_to_component(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS}, command.component))
    device:send_to_component(Meter:Get({scale = Meter.scale.electric_meter.WATTS}, command.component))
  end
  device.thread:call_with_delay(constants.MIN_DIMMING_GET_STATUS_DELAY, query_device)
end

-- set level
local function set_shade_level(self, device, cmd)
  local level = math.max(math.min(cmd.args.shadeLevel, 99), 0)
  window_shade_level_change(self, device, level, cmd)
end

-- command On
local function open(driver, device, cmd)
  window_shade_level_change(driver, device, 99, cmd)
end

-- Command Off
local function close(driver, device, cmd)
  window_shade_level_change(driver, device, 0, cmd)
end

local fibaro_roller_shutter_2 = {
  capability_handlers = {
    [capabilities.windowShadeLevel.ID] = {
      [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = set_shade_level
    },
    [capabilities.windowShade.ID] = {
      [capabilities.windowShade.commands.open.NAME] = open,
      [capabilities.windowShade.commands.close.NAME] = close
    },
  },
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.SET] = switch_binary_report_handler
    },
    [cc.BASIC] = {
      [Basic.SET] = switch_binary_report_handler
    },
    --[cc.METER] = {
      --[Meter.REPORT] = meter_report_handler
    --},
  },
  NAME = "fibaro roller shutter 2",
  can_handle = can_handle_fibaro_roller_shutter_2,
  lifecycle_handlers = {
    add = device_added
  }
}

return fibaro_roller_shutter_2
