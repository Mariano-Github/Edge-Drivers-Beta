-- Created M.Colmenarejo 2024

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
local write = require "writeAttribute"
local data_types = require "st.zigbee.data_types"

--module emit signal metrics
local signal = require "signal-metrics"

local motion_Type = capabilities["legendabsolute60149.motionType"]

local AQARA_FP1_SENSOR_FINGERPRINTS = {
  { mfr = "aqara", model = "lumi.sensor_occupy.agl1" },
}

local is_zigbee_aqara_sensor = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(AQARA_FP1_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("aqara-fp1e")
          return true, subdriver
        end
    end
  end
  return false
end

-- preferences update
local function do_preferences(self, device)
  print("***** infoChanged *********")
  
   for id, value in pairs(device.preferences) do
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:", id, "old:", oldPreferenceValue, "new:", newParameterValue)
      if id == "sensitivityFp1" then
        -- sensitivity value 1= low, 2 = Medium, 3 = high
        local value_send = tonumber(newParameterValue)
        if value_send == nil then value_send = 3 end
        local data_type = data_types.Uint8
        local cluster_id = 0xFCC0
        local attr_id = 0x010C
        local mfg_code = 0x115F
        device:send(write.custom_write_attribute(device, cluster_id, attr_id, data_type, value_send, mfg_code))
      elseif id == "changeProfileFp1e" then
        if newParameterValue == "Motion" then
          device:try_update_metadata({profile = "aqara-fp1e-motion-only"})
        else
          device:try_update_metadata({profile = "aqara-fp1e"})
          -- refresh motion type value
          local cluster_id = 0xFCC0
          local attr_id = 0x0160
          local mfg_code = 0x115F
          device:send(write.custom_read_attribute(device, cluster_id, attr_id, mfg_code))
        end
      end
    end
  end

  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID >>>", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)

  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")

  local firmware_full_version = device.data.firmwareFullVersion
  if firmware_full_version == nil then firmware_full_version = "Unknown" end
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
end

--presence handler
local function presence_handler(driver, device, value, zb_rx)
  print("<<< presence_handler >>>")
  --print("<< value:", value.value)
  if value.value == 0 then
    device:emit_event(capabilities.motionSensor.motion.inactive())
  elseif value.value == 1 then
    device:emit_event(capabilities.motionSensor.motion.active())
  end

  -- emit signal metrics
  signal.metrics(device, zb_rx)
end

--motion type handler
local function motion_type_handler(driver, device, value, zb_rx)
  print("<<< motion_type_handler >>>")
  if device.preferences.changeProfileFp1e == "MotionType" then
    --print("<< value:", value.value)
    if value.value == 2 then
      device:emit_event(motion_Type.motionType("Inactive"))
    elseif value.value == 3 then
      device:emit_event(motion_Type.motionType("LargeMotion"))
    elseif value.value == 4 then
      device:emit_event(motion_Type.motionType("SmallMotion"))
    end
  end
end

local function do_configure(self,device)

  -- sensitivity value 1= low, 2 = Medium, 3 = high
  local value_send = tonumber(device.preferences.sensitivityFp1)
  if value_send == nil then value_send = 3 end
  local data_type = data_types.Uint8
  local cluster_id = 0xFCC0
  local attr_id = 0x010C
  local mfg_code = 0x115F
  device:send(write.custom_write_attribute(device, cluster_id, attr_id, data_type, value_send, mfg_code))

  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

local function device_init(self, device)
  print("<< Device do init >>")

end

--device added
local function device_added(self, device)
  print("<<< device_added or refresh >>>")
  -- refresh presence value 
  local cluster_id = 0xFCC0
  local attr_id = 0x0142
  local mfg_code = 0x115F
  device:send(write.custom_read_attribute(device, cluster_id, attr_id, mfg_code))

  if device.preferences.changeProfileFp1e == "MotionType" then
    -- refresh motion type value
    cluster_id = 0xFCC0
    attr_id = 0x0160
    mfg_code = 0x115F
    device:send(write.custom_read_attribute(device, cluster_id, attr_id, mfg_code))
  end
end

--- do_driverSwitched
local function do_driverSwitched(self, device)
  print("<<<< DriverSwitched >>>>")
   device.thread:call_with_delay(2, function(d)
     do_configure(self, device)
   end, "configure") 
 end

local aqara_fp1e_presence_sensor = {
  NAME = "Aqara FP1E presence sensor",
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    doConfigure = do_configure,
    driverSwitched =  do_driverSwitched,
    infoChanged = do_preferences
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_added
    }
  },
  zigbee_handlers = {
    attr = {
      [0xFCC0] = {
        [0x0142] = presence_handler,
        [0x0160] = motion_type_handler
      },
    }
  },
  can_handle = is_zigbee_aqara_sensor
}

return aqara_fp1e_presence_sensor