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

local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.defaults
--local defaults = require "st.zwave.defaults"
--- @type st.zwave.CommandClass.Alarm
local Alarm = (require "st.zwave.CommandClass.Alarm")({ version = 2 })
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })

local ZWAVE_SOUND_SENSOR_FINGERPRINTS = {
  { manufacturerId = 0x014A, productType = 0x0005, productId = 0x000F } --Ecolink Firefighter
}

--- Determine whether the passed device is zwave-sound-sensor
---
--- @param driver Driver driver instance
--- @param device Device device isntance
--- @return boolean true if the device proper, else false
local function can_handle_zwave_sound_sensor(opts, driver, device, ...)
  for _, fingerprint in ipairs(ZWAVE_SOUND_SENSOR_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("zwave-sound-sensor")
      return true, subdriver
    end
  end
  return false
end

local zwave_handlers = {}

--- Default handler for alarm command class reports
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param cmd st.zwave.CommandClass.Alarm.Report
local function alarm_report_handler(driver, device, cmd)
  local alarm_type = cmd.args.z_wave_alarm_type
  print("alarm_type >>>>>",alarm_type)
  local alarm_event = cmd.args.z_wave_alarm_event
  print("alarm_event >>>>>",alarm_event)

  if alarm_type == Alarm.z_wave_alarm_type.CO then
    if alarm_event == Alarm.z_wave_alarm_event.co.CARBON_MONOXIDE_DETECTED_LOCATION_PROVIDED or alarm_event == Alarm.z_wave_alarm_event.co.CARBON_MONOXIDE_DETECTED then
      device:emit_event(capabilities.carbonMonoxideDetector.carbonMonoxide.detected())
      device:emit_event(capabilities.soundSensor.sound.detected())
    else
      device:emit_event(capabilities.carbonMonoxideDetector.carbonMonoxide.clear())
      device:emit_event(capabilities.soundSensor.sound.not_detected())
    end
  elseif alarm_type == Alarm.z_wave_alarm_type.SMOKE then
    if alarm_event == Alarm.z_wave_alarm_event.smoke.DETECTED_LOCATION_PROVIDED or alarm_event == Alarm.z_wave_alarm_event.smoke.DETECTED then
      device:emit_event(capabilities.smokeDetector.smoke.detected())
      device:emit_event(capabilities.soundSensor.sound.detected())
    else
      device:emit_event(capabilities.smokeDetector.smoke.clear())
      device:emit_event(capabilities.soundSensor.sound.not_detected())
    end
  elseif alarm_type == 7 then
    if alarm_event == 3 then
      device:emit_event(capabilities.tamperAlert.tamper.detected())
    else
      device:emit_event(capabilities.tamperAlert.tamper.clear())
    end
  else
    print("<<<< NO TAMPER, NO SMOKE & NO CO >>>>>")
    device:emit_event(capabilities.soundSensor.sound.not_detected())
    device:emit_event(capabilities.carbonMonoxideDetector.carbonMonoxide.clear())
    device:emit_event(capabilities.smokeDetector.smoke.clear())
    device:emit_event(capabilities.tamperAlert.tamper.clear())
  end
end

local function added_handler(driver, device)
  device:emit_event(capabilities.soundSensor.sound.not_detected())
  device:emit_event(capabilities.smokeDetector.smoke.clear())
  device:emit_event(capabilities.carbonMonoxideDetector.carbonMonoxide.clear())
  device:emit_event(capabilities.tamperAlert.tamper.clear())
end

local function do_init_handler(driver,device)

  -- set wakeup at initial time.
  local _node_id = driver.environment_info.hub_zwave_id
  local set_wakeup_interval = function()
    device:send(WakeUp:IntervalSet({seconds = device.preferences.wakeUpInterval * 3600, node_id = _node_id}))
  end

   -- Set the wakeup interval after 2 minutes later.
   device.thread:call_with_delay(4, set_wakeup_interval)

  --local set_normal_wakeup_interval = function()
    --device:send(WakeUp:IntervalSet({seconds = device.preferences.wakeUpInterval * 3600, node_id = _node_id }))
  --end

  -- Set the wakeup interval after 2 minutes later.
  --device.thread:call_with_delay(2*60, set_normal_wakeup_interval)
end

local zwave_sound_sensor = {
  zwave_handlers = {
    [cc.ALARM] = {
      [Alarm.REPORT] = alarm_report_handler
    }
  },
  lifecycle_handlers = {
    added = added_handler,
    init = do_init_handler
  },
  NAME = "zwave sound sensor",
  can_handle = can_handle_zwave_sound_sensor,
}

return zwave_sound_sensor
