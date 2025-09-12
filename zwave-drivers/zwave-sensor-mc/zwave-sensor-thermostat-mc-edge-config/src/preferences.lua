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

--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
--local child_devices = require "child-devices"
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })
local capabilities = require "st.capabilities"

local devices = {
  EVERSPRING_PIR = {
    MATCHING_MATRIX = {
      mfrs = 0x0060,
      product_types = 0x0001,
      product_ids = 0x0004
    },
    PARAMETERS = {
      tempAndHumidityReport = {parameter_number = 1, size = 2},
      retriggerIntervalSetting = {parameter_number = 2, size = 2}
    }
  },
  EVERSPRING_SP817 = {
    MATCHING_MATRIX = {
      mfrs = 0x0060,
      product_types = 0x0001,
      product_ids = 0x0006
    },
    PARAMETERS = {
      retriggerIntervalSetting = {parameter_number = 4, size = 2}
    }
  },
  FIBARO_FLOOD_SENSOR_ZW5 = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0B01,
      product_ids = {0x1002, 0x1003, 0x2002}
    },
    PARAMETERS = {
      alarmCancellationDelay = {parameter_number = 1, size = 2},
      acousticVisualSignals = {parameter_number = 2, size = 1},
      tempMeasurementInterval = {parameter_number = 10, size = 4},
      floodSensorTurnedOnOff = {parameter_number = 77, size = 1}
    }
  },
  FIBARO_DOOR_WINDOW_SENSOR_WITH_TEMPERATURE = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = {0x0701, 0x0700},
      product_ids = {0x2001, 0x1000, 0x2000, 0x1001}
    },
    PARAMETERS = {
      operationMode = {parameter_number = 1, size = 1}, -- Modified by M Colmenarejo
      alarmStatus = {parameter_number = 2, size = 1},
      visualLedIndications = {parameter_number = 3, size = 1},
      delayOfTamperAlarmCancel = {parameter_number = 30, size = 2},
      reportTamperAlarmCancel = {parameter_number = 31, size = 1},
      tempMeasurementInterval = {parameter_number = 50, size = 2},
      tempReportsThreshold = {parameter_number = 51, size = 2},
      intervalOfTempReports = {parameter_number = 52, size = 2},
      temperatureOffset = {parameter_number = 53, size = 4},
      temperatureAlarmReports = {parameter_number = 54, size = 1},
      highTempThreshold = {parameter_number = 55, size = 2},
      lowTempThreshold = {parameter_number = 56, size = 2}
    }
  },
  EZMULTIPLI = {
    MATCHING_MATRIX = {
        mfrs = 0x001E,
        product_types = 0x0004,
        product_ids = 0x0001
    },
    PARAMETERS = {
      onTime = {parameter_number = 1, size = 1},
      onLevel = {parameter_number = 2, size = 1},
      liteMin = {parameter_number = 3, size = 1},
      tempMin = {parameter_number = 4, size = 1},
      tempAdj = {parameter_number = 5, size = 1}
    }
  },
  FIBARO_DOOR_WINDOW_SENSOR_2 = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0702,
      product_ids = {0x1000, 0x2000, 0x3000}
    },
    PARAMETERS = {
      doorWindowState = {parameter_number = 1, size = 1},
      visualLedIndications = {parameter_number = 2, size = 1},
      tamperCancelDelay = {parameter_number = 30, size = 2},
      cancelTamperReport = {parameter_number = 31, size = 1},
      tempMeasurementInterval = {parameter_number = 50, size = 2},
      tempReportsThreshold = {parameter_number = 51, size = 2},
      temperatureAlarmReports = {parameter_number = 54, size = 1},
      highTempThreshold = {parameter_number = 55, size = 2},
      lowTempThreshold = {parameter_number = 56, size = 2}
    }
  },
  AEOTEC_MULTISENSOR_6 = {
    MATCHING_MATRIX = {
      mfrs = {0x0086, 0x016A},
      product_types = {0x0002, 0x0102, 0x0202},
      product_ids = 0x0064
    },
    PARAMETERS = {
      motionDelayTime = {parameter_number = 3, size = 2},
      motionSensitivity = {parameter_number = 4, size = 1},
      reportInterval = {parameter_number = 111, size = 4}
    }
  },
  AEOTEC_MULTISENSOR_7 = {
    MATCHING_MATRIX = {
      mfrs = 0x0371,
      product_types = {0x0002, 0x0102, 0x0202},
      product_ids = 0x0018
    },
    PARAMETERS = {
      motionDelayTime = {parameter_number = 3, size = 2},
      motionSensitivity = {parameter_number = 4, size = 1},
      reportInterval = {parameter_number = 111, size = 2}
    }
  },
  FIBARO_MOTION_SENSOR = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0801,
      product_ids = {0x1001, 0x1002, 0x2001, 0x2002}
    },
    PARAMETERS = {
      motionSensitivityLevel = {parameter_number = 1, size = 2},
      motionBlindTime = {parameter_number = 2, size = 1},
      motionCancelationDelay = {parameter_number = 6, size = 2},
      motionOperatingMode = {parameter_number = 8, size = 1},
      motionNightDay = {parameter_number = 9, size = 2},
      tamperCancelationDelay = {parameter_number = 22, size = 2},
      tamperOperatingMode = {parameter_number = 24, size = 1},
      illuminanceThreshold = {parameter_number = 40, size = 2},
      illuminanceInterval = {parameter_number = 42, size = 2},
      temperatureThreshold = {parameter_number = 60, size = 2},
      ledMode = {parameter_number = 80, size = 1},
      ledBrightness = {parameter_number = 81, size = 1},
      ledLowBrightness = {parameter_number = 82, size = 2},
      ledHighBrightness = {parameter_number = 83, size = 2}
    }
  },
  FIBARO_MOTION_SENSOR_OLD = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0800,
      product_ids = {0x1001, 0x2001}
    },
    PARAMETERS = {
      motionSensitivityLevel = {parameter_number = 1, size = 1},
      motionBlindTime = {parameter_number = 2, size = 1},
      motionCancelationDelay = {parameter_number = 6, size = 2},
      motionOperatingMode = {parameter_number = 8, size = 1},
      motionNightDay = {parameter_number = 9, size = 2},
      tamperCancelationDelay = {parameter_number = 22, size = 2},
      tamperOperatingMode = {parameter_number = 24, size = 1},
      illuminanceThreshold = {parameter_number = 40, size = 2},
      illuminanceInterval = {parameter_number = 42, size = 2},
      temperatureThreshold = {parameter_number = 60, size = 2},
      temperatureInterval = {parameter_number = 62, size = 2},
      ledMode = {parameter_number = 80, size = 1},
      ledBrightness = {parameter_number = 81, size = 1},
      ledLowBrightness = {parameter_number = 82, size = 2},
      ledHighBrightness = {parameter_number = 83, size = 2}
    }
  },
  SECURE_SES303 = {
    MATCHING_MATRIX = {
      mfrs = 0x0059,
      product_types = 0x000D,
      product_ids = 0x0003
    },
    PARAMETERS = {
      deltaTemp = {parameter_number = 1, size = 1},
      tempIntervalReport = {parameter_number = 2, size = 1},
      deltaHumidity = {parameter_number = 3, size = 1},
      humidityIntervalReport = {parameter_number = 4, size = 1},
    }
  }
}
local preferences = {}

preferences.update_preferences = function(driver, device, args)
  local prefs = preferences.get_device_parameters(device)

    for id, value in pairs(device.preferences) do

      if prefs ~= nil then
        --if not (args and args.old_st_store) or (args.old_st_store.preferences[id] ~= value and prefs and prefs[id]) then
        if not (args and args.old_st_store and args.old_st_store.preferences) or (args.old_st_store.preferences[id] ~= value and prefs and prefs[id]) then --CHAD-12274 fixes occasional null pointer
          local new_parameter_value = preferences.to_numeric_value(device.preferences[id])
          --2's complement value if needed
          if prefs[id].size == 4 and new_parameter_value > 2147483647 then
            new_parameter_value = new_parameter_value - 4294967296
          elseif prefs[id].size == 2 and new_parameter_value > 32767 then
            new_parameter_value = new_parameter_value - 65536
          elseif prefs[id].size == 1 and new_parameter_value > 127 then
            new_parameter_value = new_parameter_value - 256
          end
          print("<<<< parameter_number =",prefs[id].parameter_number)
          print("<<<< size =",prefs[id].size)
          print("<<<< configuration_value =",new_parameter_value)
          device:send(Configuration:Set({parameter_number = prefs[id].parameter_number, size = prefs[id].size, configuration_value = new_parameter_value}))

          device.thread:call_with_delay(1, function()
            device:send(Configuration:Get({ parameter_number = prefs[id].parameter_number }))
          end)
        end
      else
       if id == "reportingInterval" then
          if device.preferences.reportingInterval ~= nil and args.old_st_store.preferences.reportingInterval ~= device.preferences.reportingInterval then
            device:send(WakeUp:IntervalSet({node_id = driver.environment_info.hub_zwave_id, seconds = device.preferences.reportingInterval*60}))
            device.thread:call_with_delay(2, function()
              device:send(WakeUp:IntervalGet({}))
            end)
          end
        end
      end
    end
    -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

preferences.get_device_parameters = function(zw_device)
  for _, device in pairs(devices) do
    if zw_device:id_match(
      device.MATCHING_MATRIX.mfrs,
      device.MATCHING_MATRIX.product_types,
      device.MATCHING_MATRIX.product_ids) then
      return device.PARAMETERS
    end
  end
  return nil
end

preferences.to_numeric_value = function(new_value)
  local numeric = tonumber(new_value)
  if numeric == nil then -- in case the value is boolean
    numeric = new_value and 1 or 0
  end
  return numeric
end

return preferences
