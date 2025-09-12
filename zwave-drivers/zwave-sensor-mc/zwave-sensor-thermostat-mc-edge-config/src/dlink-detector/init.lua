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

local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.SensorMultilevel
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({ version = 5 })
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({version=2})
--- @type st.zwave.CommandClass.SensorBinary
--local SensorBinary = (require "st.zwave.CommandClass.SensorBinary")({version=2})
--- @type st.zwave.CommandClass.Notification
--local Notification = (require "st.zwave.CommandClass.Notification")({version=4})

local DLINK_DETECTOR_FINGERPRINTS = {
  { manufacturerId = 0x0108, productType = 0x0002, productId = 0x000D }, -- Dlink Motion Detector DCH-Z120
  { manufacturerId = 0x0108, productType = 0x0002, productId = 0x000E } -- Dlink Motion Detector DCH-Z110
}

--- Determine whether the passed device is zwave-plus-motion-temp-sensor
---
--- @param driver Driver driver instance
--- @param device Device device isntance
--- @return boolean true if the device proper, else false
local function can_handle_dlink_motion_detector(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(DLINK_DETECTOR_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("dlink-detector")
      return true, subdriver
    end
  end
  return false
end

--- @param self st.zwave.Driver
--- @param device st.zwave.Device
--- @param cmd st.zwave.CommandClass.SensorMultilevel.Report
local function illuminance_report_handler(self, device, cmd)
  if (cmd.args.sensor_type == SensorMultilevel.sensor_type.LUMINANCE and
      cmd.args.scale == SensorMultilevel.scale.luminance.PERCENTAGE) then -- Dlink devices send percentage instead lux
  --if cmd.args.sensor_type == SensorMultilevel.sensor_type.LUMINANCE then
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.illuminanceMeasurement.illuminance({value = cmd.args.sensor_value, unit = "lux"}))
  end
end

local function wakeup_notification(driver, device, cmd)

  --if device.zwave_product_id== 0x000D then -- motion sensor
    --device:send(SensorBinary:Get({sensor_type = SensorBinary.sensor_type.TAMPER}))
  --elseif device.zwave_product_id== 0x000E then -- contact sensor
    --device:send(Notification:Get({}))
    --device:send(SensorBinary:Get({sensor_type = SensorBinary.sensor_type.TAMPER}))
  --end

  for timer in pairs(device.thread.timers) do
    if device.preferences.logDebugPrint == true then
      print("<<< Cancel GET Tamper timer >>>")
    end
    device.thread:cancel_timer(timer)
  end
  local tamper_reset = function(d)
    device:emit_event(capabilities.tamperAlert.tamper.clear())
  end

  device.thread:call_with_delay(10, tamper_reset, "tamper reset")

end

local dlink_detector = {
  zwave_handlers = {
    [cc.SENSOR_MULTILEVEL] = {
      [SensorMultilevel.REPORT] = illuminance_report_handler
    },
    [cc.WAKE_UP] = {
      [WakeUp.NOTIFICATION] = wakeup_notification
    }
  },
  NAME = "Dlink detector",
  can_handle = can_handle_dlink_motion_detector
}

return dlink_detector
