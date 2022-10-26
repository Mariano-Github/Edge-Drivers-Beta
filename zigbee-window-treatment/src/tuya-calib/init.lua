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
local zcl_clusters = require "st.zigbee.zcl.clusters"
local window_preset_defaults = require "st.zigbee.defaults.windowShadePreset_defaults"
local window_shade_defaults = require "st.zigbee.defaults.windowShade_defaults"
local device_management = require "st.zigbee.device_management"
local Level = zcl_clusters.Level

local device_Info = capabilities["legendabsolute60149.deviceInfo"]

local ZIGBEE_WINDOW_SHADE_FINGERPRINTS = {
    { mfr = "_TZ3000_vd43bbfq", model = "TS130F" },
    { mfr = "_TZ3000_fccpjz5z", model = "TS130F" },
    { mfr = "_TZ3000_4uuaja4a", model = "TS130F" },
    { mfr = "_TZ3000_zirycpws", model = "TS130F" },
    { mfr = "_TZ3000_1dd0d5yi", model = "TS130F" }
}

local is_zigbee_window_shade = function(opts, driver, device)
  for _, fingerprint in ipairs(ZIGBEE_WINDOW_SHADE_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          return true
      end
  end

  return false
end

local function curtain_switch_handler(driver, device, value, zb_rx)
  print("<<< Curtain Switch Value >>>",value.value)
  local str = "Stop"
  local curtain_switch = value.value
  local time = "UTC Time: "..os.date("%H:%M:%S",os.time())
  if curtain_switch == 0 then
    str = " Open or Up"
  elseif curtain_switch == 2 then
    str = " Close or Down"
  end

  str = time .. str

  device:emit_event(device_Info.deviceInfo(str))

end

local function accurate_calibration_handler(driver, device, value, zb_rx)
  print("<<< Accurate calibration Value >>>",value.value)
  local accurate_calibration = value.value
  local time = "UTC Time: "..os.date("%H:%M:%S",os.time())
  local str = " Calibration finished"
  if accurate_calibration == 0 then
    str = " Calibration started"
  end

  str = time .. str

  device:emit_event(device_Info.deviceInfo(str))
 
end

local function travel_time_handler(driver, device, value, zb_rx)
  print("<<< Travel time Value >>>",value.value)
  local travel_time = value.value / 10
  local str = "Calibration Total Time: "..travel_time.." Sec"

  device:emit_event(device_Info.deviceInfo(str))

end

local function do_added(self,device)
  if device.preferences.performCalibration == "1" then
    device:emit_event(device_Info.deviceInfo("Run Mode in Settings"))
  else
    device:emit_event(device_Info.deviceInfo("Calibration Mode in Settings"))
  end
end

local tuya_handler = {
  NAME = "Tuya Device Handler",
  capability_handlers = {
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.WindowCovering.ID] = {
        [0xF000] = curtain_switch_handler
      },
      [zcl_clusters.WindowCovering.ID] = {
        [0xF001] = accurate_calibration_handler
      },
      [zcl_clusters.WindowCovering.ID] = {
        [0xF003] = travel_time_handler
      }
    }
  },
  lifecycle_handlers = {
    added = do_added
  },
  can_handle = is_zigbee_window_shade,
}

return tuya_handler
