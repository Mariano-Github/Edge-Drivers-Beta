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

local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery = capabilities.battery
local utils = require "st.utils"

local is_frient_smoke_detector = function(opts, driver, device)
  if device:get_manufacturer() == "frient A/S" or device:get_manufacturer() == "LUMI" then
    return true
  end
  return false
end

local battery_handler = function(driver, device, value, zb_rx)
  -- Emit Battery voltage event
    
     if device:get_manufacturer() == "frient A/S" then
      local minVolts = 2.3
      local maxVolts = 3.0
      
      local battery_pct = math.floor(((((value.value / 10) - minVolts) + 0.05) / (maxVolts - minVolts)) * 100)
      device:emit_event(battery.battery(battery_pct))
    else
      local minVolts = 2.5
      local maxVolts = 3.0
  
      local battery_pct = math.floor(((((value.value / 10) - minVolts) + 0.05) / (maxVolts - minVolts)) * 100)
      device:emit_event(battery.battery(battery_pct))
    end
  end

local frient_smoke_detector = {
  NAME = "Freint Smoke Detector",
  zigbee_handlers = {
    attr = {
        [zcl_clusters.PowerConfiguration.ID] = {
          [zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID] = battery_handler
        }
    }
},
  lifecycle_handlers = {
    init = battery_defaults.build_linear_voltage_init(2.3, 3.0)
  },
  can_handle = is_frient_smoke_detector
}

return frient_smoke_detector
