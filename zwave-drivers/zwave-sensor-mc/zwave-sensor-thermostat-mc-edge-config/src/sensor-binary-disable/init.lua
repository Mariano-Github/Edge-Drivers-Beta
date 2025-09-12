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

--local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.SensorBinary
local SensorBinary = (require "st.zwave.CommandClass.SensorBinary")({version=2})
local Battery = (require "st.zwave.CommandClass.Battery")({ version = 1})
--- @type st.zwave.CommandClass.WakeUp
--local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 1 })

local SENSOR_BINARY_DISABLE = {
  { manufacturerId = 0x0260, productType = 0x0168, productId = 0x0168 } -- Heiman HS1DS-Z Contact Sensor
}

---
--- @param driver Driver driver instance
--- @param device Device device instance
--- @return boolean true if the device proper, else false
local function can_handle_sensor_binary_disable(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(SENSOR_BINARY_DISABLE) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("sensor-binary-disable")
      return true, subdriver
    end
  end
  return false
end


--- @param cmd st.zwave.CommandClass.SensorBinary.Report
local function sensor_binary_report_handler(self, device, cmd)
  -- no emit the event for this c.c. due this device send status by c.c. NOTIFICATION defaults
end

--- refresh added in stock driver
local function wakeup_notification(driver, device, cmd)
  device:send(Battery:Get({}))
end

local sensor_binary_disable = {
  zwave_handlers = {
    [cc.SENSOR_BINARY] = {
      [SensorBinary.REPORT] = sensor_binary_report_handler
    },
    --[cc.WAKE_UP] = {
      --[WakeUp.NOTIFICATION] = wakeup_notification
    --}
  },
  lifecycle_handlers = {
  },
  NAME = "Sensor Binary disable handler",
  can_handle = can_handle_sensor_binary_disable
}

return sensor_binary_disable
