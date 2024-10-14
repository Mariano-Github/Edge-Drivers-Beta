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

local devices = {
  HEIMAN_SMOK_V16 = {
    FINGERPRINTS = {
      { mfr = "Heiman", model = "SMOK_V16" },
      { mfr = "HEIMAN", model = "SmokeSensor-N-3.0"},
      { mfr = "HEIMAN", model = "SmokeSensor-N"},
      { mfr = "Heiman", model = "SMOK_YDLV10"},
      { mfr = "Trust", model = "COSensor-EM"},
      { mfr = "_TYZB01_dsjszp0x", model = "TS0205"},
      { mfr = "_TZ3000_hl7yraue", model = "TS0205"},
    },
    CONFIGURATION = {
      {
        cluster = PowerConfiguration.ID,
        attribute = PowerConfiguration.attributes.BatteryPercentageRemaining.ID,
        minimum_interval = 30,
        maximum_interval = 300,
        data_type = PowerConfiguration.attributes.BatteryPercentageRemaining.base_type,
        reportable_change = 1
      },
      --{
        --cluster = IASZone.ID,
        --attribute = IASZone.attributes.ZoneStatus.ID,
        --minimum_interval = 30,
        --maximum_interval = 180,
        --data_type = IASZone.attributes.ZoneStatus.base_type,
        --reportable_change = 1
      --}
    }
  },
  GAS_DETECTOR = {
    FINGERPRINTS = {
      { mfr = "_TYZB01_mfccmeio", model = "TS0204" },
      { mfr = "_TYZB01_0w3d5uw", model = "TS0204" },
      { mfr = "feibit", model = "FNB56-GAS05FB1.4" },
      { mfr = "LUMI", model = "lumi.sensor_gas.acn02" }
    },
    CONFIGURATION = {
      {
        cluster = IASZone.ID,
        attribute = IASZone.attributes.ZoneStatus.ID,
        minimum_interval = 30,
        maximum_interval = 180,
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