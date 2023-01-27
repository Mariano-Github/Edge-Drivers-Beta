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

local clusters = require "st.zigbee.zcl.clusters"

local IASZone = clusters.IASZone
local PowerConfiguration = clusters.PowerConfiguration
--local TemperatureMeasurement = clusters.TemperatureMeasurement
local PollControl = clusters.PollControl

local devices = {
  EWELINK_HEIMAN = {
    FINGERPRINTS = {
      { mfr = "eWeLink", model = "DS01" },
      { mfr = "_TZ3000_f1hmoyj4", model = "TS0203" },
      --{ mfr = "eWeLink", model = "SNZB-04P" },
      --{ mfr = "HEIMAN", model = "DoorSensor-N" }
    },
    CONFIGURATION = {
      {
        cluster = PowerConfiguration.ID,
        attribute = PowerConfiguration.attributes.BatteryPercentageRemaining.ID,
        minimum_interval = 30,
        maximum_interval = 600,
        data_type = PowerConfiguration.attributes.BatteryPercentageRemaining.base_type,
        reportable_change = 1
      },
      {
        cluster = IASZone.ID,
        attribute = IASZone.attributes.ZoneStatus.ID,
        minimum_interval = 30,
        maximum_interval = 300,
        data_type = IASZone.attributes.ZoneStatus.base_type,
        reportable_change = 1
      }
    }
  },
}

local configurations = {}

configurations.get_device_configuration = function(zigbee_device)
  for _, device in pairs(devices) do
    for _, fingerprint in pairs(device.FINGERPRINTS) do
      if zigbee_device:get_manufacturer() == fingerprint.mfr and zigbee_device:get_model() == fingerprint.model then
        return device.CONFIGURATION
      end
    end
  end
  return nil
end

return configurations