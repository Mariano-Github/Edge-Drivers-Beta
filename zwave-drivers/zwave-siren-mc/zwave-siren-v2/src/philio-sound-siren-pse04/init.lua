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

local cc = require "st.zwave.CommandClass"
local capabilities = require "st.capabilities"
local constants = require "st.zwave.constants"
local Basic = (require "st.zwave.CommandClass.Basic")({version =1})
--local SensorBinary = (require "st.zwave.CommandClass.SensorBinary")({version=2})
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
--local preferencesMap = require "preferences"

local PHILIO_SOUND_SIREN = {
  { manufacturerId = 0x013C, productType = 0x0004, productId = 0x0084 }
}

local TAMPER_CLEAR_DELAY = 5

local function can_handle_philio_sound_siren(opts, driver, device, ...)
  for _, fingerprint in ipairs(PHILIO_SOUND_SIREN) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("philio-sound-siren-pse04")
      return true, subdriver
    end
  end
  return false
end

local function device_added(self, device)
  device:refresh()
end

local function device_init(self, device)
  -- change to this profile if device was installed prior to this update profile
  device:try_update_metadata({profile = "philio-alarm-battery-temp-tamper"})
  device:emit_event(capabilities.tamperAlert.tamper.clear())
end

local function siren_set_helper(driver, device, value, command)
  local delay = constants.DEFAULT_GET_STATUS_DELAY
  local set = Basic:Set({
    value=value
  })
  local get = Basic:Get({})
  device:send_to_component(set, command.component)
  local query_device = function()
    device:send_to_component(get, command.component)
  end
  device.thread:call_with_delay(delay, query_device)
end

--- Issue a set siren command to the specified device.
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command table ST level capability command
local function handle_alarm_on(driver, device, command)
  local value = tonumber(device.preferences.sound)
  if value == nil then value = 4 end
  siren_set_helper(driver, device, value, command)
end

local function handle_sound_off(driver, device)
  device:send(Basic:Set({value=0x00}))
end

local function deactivateTamper(device)
  device:emit_event(capabilities.tamperAlert.tamper.clear())
end

local function activateTamper(device)
  device:emit_event(capabilities.tamperAlert.tamper.detected())
  device.thread:call_with_delay(
    TAMPER_CLEAR_DELAY,
    function(d)
      deactivateTamper(device)
    end
  )
end

local function notification_handler(driver, device, cmd)
  local notification_type = cmd.args.notification_type
  local notification_event = cmd.args.event

  if (notification_type == Notification.notification_type.HOME_SECURITY) then
    if notification_event == Notification.event.home_security.TAMPERING_PRODUCT_COVER_REMOVED then
      activateTamper(device)
    elseif notification_event == Notification.event.home_security.STATE_IDLE then
      deactivateTamper(device)
    end
  elseif cmd.args.notification_type == Notification.notification_type.SIREN then
    if cmd.args.event == Notification.event.siren.ACTIVE then
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.alarm.alarm.both())
      if device:supports_capability_by_id(capabilities.switch.ID) then
        device:emit_event_for_endpoint(cmd.src_channel, capabilities.switch.switch.on())
      end
    elseif cmd.args.event == Notification.event.siren.STATE_IDLE then
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.alarm.alarm.off())
      if device:supports_capability_by_id(capabilities.switch.ID) then
        device:emit_event_for_endpoint(cmd.src_channel, capabilities.switch.switch.off())
      end
    end
  end
end


local philio_sound_siren_pse04 = {
  NAME = "Philio sound siren PSE04",
  can_handle = can_handle_philio_sound_siren,
  lifecycle_handlers = {
    added = device_added,
    init = device_init
  },
  zwave_handlers = {
    [cc.NOTIFICATION] = {
      [Notification.REPORT] = notification_handler
    }
  },
  capability_handlers = {
    [capabilities.alarm.ID] = {
      [capabilities.alarm.commands.siren.NAME]  = handle_alarm_on,
      [capabilities.alarm.commands.strobe.NAME] = handle_alarm_on,
      [capabilities.alarm.commands.both.NAME]   = handle_alarm_on,
      [capabilities.alarm.commands.off.NAME]    = handle_sound_off
    },
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = handle_alarm_on,
      [capabilities.switch.commands.off.NAME] = handle_sound_off
    }
  }
}

return philio_sound_siren_pse04