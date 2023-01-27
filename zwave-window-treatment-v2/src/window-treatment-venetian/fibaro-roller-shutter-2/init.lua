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
local capabilities = require "st.capabilities"

local FIBARO_ROLLER_SHUTTER_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0301, model = 0x1001}, -- Fibaro Roller Shutter 2 FGRM-222
  {mfr = 0x010F, prod = 0x0302, model = 0x1000}, -- Fibaro Roller Shutter 2 FGR-222
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
  local parameter_number = cmd.args.parameter_number
  local configuration_value = cmd.args.configuration_value

  if parameter_number == CALIBRATION_CONFIGURATION then 
    local calibration_status
    --if configuration_value == 0 then
      --calibration_status = CLB_NOT_STARTED
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
  device:set_field(CALIBRATION, CLB_NOT_STARTED)
  device:do_refresh()
end

---switch_binary_report_handler for switch physical change
local function switch_binary_report_handler(driver, device, cmd)
  print("cmd.args.switch_value >>>>>>>>>>>>>",cmd.args.switch_value)
  if cmd.args.switch_value == 255  then
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShade.windowShade.open())
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShadeLevel.shadeLevel(100))
  else
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShade.windowShade.closed())
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.windowShadeLevel.shadeLevel(0))
  end

  local query_device = function()
   device:send(SwitchMultilevel:Get({},{dst_channels = {cmd.src_channel}}))
   device:send(Basic:Get({},{dst_channels = {cmd.src_channel}}))
   device:send(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS},{dst_channels = {cmd.src_channel}}))
   device:send(Meter:Get({scale = Meter.scale.electric_meter.WATTS},{dst_channels = {cmd.src_channel}}))
  end
  device.thread:call_with_delay(constants.MIN_DIMMING_GET_STATUS_DELAY, query_device)

  --device.thread:call_with_delay(4, 
  --function()
    --device:send(Meter:Get({scale = Meter.scale.electric_meter.WATTS},{dst_channels = {cmd.src_channel}}))
  --end)

end


local fibaro_roller_shutter_2 = {
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.SET] = switch_binary_report_handler
    },
  },
  NAME = "fibaro roller shutter 2",
  can_handle = can_handle_fibaro_roller_shutter_2,
  lifecycle_handlers = {
    add = device_added
  }
}

return fibaro_roller_shutter_2
