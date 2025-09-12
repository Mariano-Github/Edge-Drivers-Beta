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
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })
--- @type st.zwave.CommandClass.Configuration
--local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 1 })
--- @type st.zwave.CommandClass.Notification
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })

local NORTEK_CONTAC_SENSOR_FINGERPRINTS = {
  { manufacturerId = 0x014F, productType = 0x2001, productId = 0x0102 } -- Go Control (nortek)
}

--- Determine whether the passed device is zwave-plus-motion-temp-sensor
---
--- @param driver Driver driver instance
--- @param device Device device isntance
--- @return boolean true if the device proper, else false
local function can_handle_nortek_contact_sensor(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(NORTEK_CONTAC_SENSOR_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("nortek-contact-sensor")
      return true, subdriver
    end
  end
  return false
end

--- Handler for notification report command class from sensor
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
--- @param cmd st.zwave.CommandClass.Notification.Report
local function notification_report_handler(self, device, cmd)
  local event = nil
  if cmd.args.notification_type == Notification.notification_type.HOME_SECURITY then
    if cmd.args.event == Notification.event.home_security.INTRUSION then
      if  cmd.args.alarm_level == 0 then
        event = capabilities.contactSensor.contact.closed()
      elseif cmd.args.alarm_level == 255 then
        event = capabilities.contactSensor.contact.open()
      end
    elseif cmd.args.event == Notification.event.home_security.UNKNOWN_EVENT_STATE then
      if  cmd.args.alarm_level == 255 then
        event = capabilities.contactSensor.contact.closed()
      elseif cmd.args.alarm_level == 0 then
        event = capabilities.contactSensor.contact.open()
      end
    elseif cmd.args.event == Notification.event.home_security.TAMPERING_PRODUCT_COVER_REMOVED then
      if  cmd.args.alarm_level == 255 then
        event = capabilities.tamperAlert.tamper.detected()
      elseif cmd.args.alarm_level == 0 then
        event = capabilities.tamperAlert.tamper.clear()
      end
    end
  end
  if event ~= nil then device:emit_event(event) end
end

-- Tamper alert off
local function notification_wake_handler(self, device, cmd)
  local event = capabilities.tamperAlert.tamper.clear()
  if event ~= nil then device:emit_event(event) end
end

local nortek_contact_sensor = {
  zwave_handlers = {
    [cc.NOTIFICATION] = {
      [Notification.REPORT] = notification_report_handler
    },
    [cc.WAKE_UP] = {
      [WakeUp.NOTIFICATION] = notification_wake_handler
    },
  },
  lifecycle_handlers = {
    --doConfigure = do_configure,
  },
  NAME = "Nortek contact sensorr",
  can_handle = can_handle_nortek_contact_sensor
}

return nortek_contact_sensor
