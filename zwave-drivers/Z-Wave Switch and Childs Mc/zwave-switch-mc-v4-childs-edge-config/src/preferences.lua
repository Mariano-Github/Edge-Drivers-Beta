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
-- Modified by M. Colmenarejo

--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
local child_devices = require "child-devices"

local devices = {
  INOVELLI = {
    MATCHING_MATRIX = {
      mfrs = 0x031E,
      product_types = {0x0001, 0x0003},
      product_ids = 0x0001
    },
    PARAMETERS = {
      dimmingSpeed = {parameter_number = 1, size = 1},
      dimmingSpeedZWave = {parameter_number = 2, size = 1},
      rampRate = {parameter_number = 3, size = 1},
      rampRateZWave = {parameter_number = 4, size = 1},
      minimumDimLevel = {parameter_number = 5, size = 1},
      maximumDimLevel = {parameter_number = 6, size = 1},
      invertSwitch = {parameter_number = 7, size = 1},
      autoOffTimer = {parameter_number = 8, size = 2},
      powerOnState = {parameter_number = 11, size = 1},
      ledIndicatorIntensity = {parameter_number = 14, size = 1},
      ledIntensityWhenOff = {parameter_number = 15, size = 1},
      ledIndicatorTimeout = {parameter_number = 17, size = 1},
      acPowerType = {parameter_number = 21, size = 1},
      switchType = {parameter_number = 22, size = 1}
    }
  },
  INOVELLI_NZW31 = {
    MATCHING_MATRIX = {
      mfrs = {0x0312, 0x015D, 0x051D},
      product_types = {0x1F00, 0x01F01, 0x1F02, 0xB111, 0x0118},
      product_ids = {0x1F00, 0x1F01, 0x1F02, 0x251C, 0x1E1C}
    },
    PARAMETERS = {
      dimmingStep = {parameter_number = 1, size = 1},
      minimumLevel = {parameter_number = 2, size = 1},
      ledIndicator = {parameter_number = 3, size = 1},
      invert = {parameter_number = 4, size = 1},
      autoOff = {parameter_number = 5, size = 2},
      defaultLocal = {parameter_number = 8, size = 1},
      defaultZWave = {parameter_number = 9, size = 1},
    }
  },
  INOVELLI_NZW30 = {
    MATCHING_MATRIX = {
      mfrs = {0x0312, 0x015D},
      product_types = {0x1E00, 0x1E01, 0x1E02, 0xB111, 0x0117},
      product_ids = {0x1E00, 0x1E01, 0x1E02, 0x1E1C}
    },
    PARAMETERS = {
      ledIndicator = {parameter_number = 3, size = 1},
      invert = {parameter_number = 4, size = 1},
      autoOff = {parameter_number = 5, size = 2},
    }
  },
  QUBINO_FLUSH_DIMMER = {
    MATCHING_MATRIX = {
      mfrs = 0x0159,
      product_types = 0x0001,
      product_ids = 0x0051
    },
    PARAMETERS = {
      input1SwitchType = {parameter_number = 1, size = 1},
      input2SwitchType = {parameter_number = 2, size = 1},
      enableAdditionalSwitch = {parameter_number = 20, size = 1},
      enableDoubleClick = {parameter_number = 21, size = 1},
      saveStateAfterPowerFail = {parameter_number = 30, size = 1},
      minimumDimmingValue = {parameter_number = 60, size = 1},
      dimmingTimeSoftOnOff = {parameter_number = 65, size = 2},
      dimmingTimeKeyPressed = {parameter_number = 66, size = 1},
      dimmingDuration = {parameter_number = 68, size = 1}
    }
  },
  QUBINO_DIN_DIMMER = {
    MATCHING_MATRIX = {
      mfrs = 0x0159,
      product_types = 0x0001,
      product_ids = 0x0052
    },
    PARAMETERS = {
      input1SwitchType = {parameter_number = 1, size = 1},
      enableDoubleClick = {parameter_number = 21, size = 1},
      saveStateAfterPowerFail = {parameter_number = 30, size = 1},
      minimumDimmingValue = {parameter_number = 60, size = 1},
      dimmingTimeSoftOnOff = {parameter_number = 65, size = 2},
      dimmingTimeKeyPressed = {parameter_number = 66, size = 1},
      dimmingDuration = {parameter_number = 68, size = 1}
    }
  },
  QUBINO_FLUSH_DIMMER_0_10V = {
    MATCHING_MATRIX = {
      mfrs = 0x0159,
      product_types = 0x0001,
      product_ids = 0x0053
    },
    PARAMETERS = {
      input1SwitchType = {parameter_number = 1, size = 1},
      enableDoubleClick = {parameter_number = 21, size = 1},
      saveStateAfterPowerFail = {parameter_number = 30, size = 1},
      minimumDimmingValue = {parameter_number = 60, size = 1},
      dimmingTimeSoftOnOff = {parameter_number = 65, size = 2},
      dimmingTimeKeyPressed = {parameter_number = 66, size = 1},
      dimmingDuration = {parameter_number = 68, size = 1}
    }
  },
  QUBINO_MINI_DIMMER = {
    MATCHING_MATRIX = {
      mfrs = 0x0159,
      product_types = 0x0001,
      product_ids = 0x0055
    },
    PARAMETERS = {
      input1SwitchType = {parameter_number = 1, size = 1},
      enableDoubleClick = {parameter_number = 21, size = 1},
      saveStateAfterPowerFail = {parameter_number = 30, size = 1},
      minimumDimmingValue = {parameter_number = 60, size = 1},
      dimmingTimeSoftOnOff = {parameter_number = 65, size = 2},
      dimmingTimeKeyPressed = {parameter_number = 66, size = 1},
      dimmingDuration = {parameter_number = 68, size = 1},
      calibrationTrigger = {parameter_number = 71, size = 1}
    }
  },
  QUBINO_FLUSH_1_2_RELAY = {
    MATCHING_MATRIX = {
      mfrs = 0x0159,
      product_types = 0x0002,
      product_ids = { 0x0051, 0x0052 }
    },
    PARAMETERS = {
      input1SwitchType = {parameter_number = 1, size = 1},
      input2SwitchType = {parameter_number = 2, size = 1},
      saveStateAfterPowerFail = {parameter_number = 30, size = 1},
      outputQ1SwitchSelection = {parameter_number = 63, size = 1},
      outputQ2SwitchSelection = {parameter_number = 64, size = 1}
    }
  },
  QUBINO_FLUSH_1D_RELAY = {
    MATCHING_MATRIX = {
      mfrs = 0x0159,
      product_types = 0x0002,
      product_ids = 0x0053
    },
    PARAMETERS = {
      input1SwitchType = {parameter_number = 1, size = 1},
      saveStateAfterPowerFail = {parameter_number = 30, size = 1},
      outputQ1SwitchSelection = {parameter_number = 63, size = 1}
    }
  },
  FIBARO_WALLI_DIMMER = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x1C01,
      product_ids = 0x1000
    },
    PARAMETERS = {
      ledFrameColourWhenOn = {parameter_number = 11, size = 1},
      ledFrameColourWhenOff = {parameter_number = 12, size = 1},
      ledFrameBrightness = {parameter_number = 13, size = 1},
      dimmStepSizeManControl = {parameter_number = 156, size = 1},
      timeToPerformDimmingStep = {parameter_number = 157, size = 2},
      doubleClickSetLevel = {parameter_number = 165, size = 1},
      buttonsOrientation = {parameter_number = 24, size = 1}
    }
  },
  FIBARO_WALLI_DOUBLE_SWITCH = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x1B01,
      product_ids = 0x1000
    },
    PARAMETERS = {
      ledFrameColourWhenOn = {parameter_number = 11, size = 1},
      ledFrameColourWhenOff = {parameter_number = 12, size = 1},
      ledFrameBrightness = {parameter_number = 13, size = 1},
      buttonsOperation = {parameter_number = 20, size = 1},
      buttonsOrientation = {parameter_number = 24, size = 1},
      outputsOrientation = {parameter_number = 25, size = 1}
    }
  },
  FIBARO_DOUBLE = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = {0x0202, 0x0203},
      product_ids = {0x1000, 0x2000, 0x3000}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 9, size = 1},
      ch1OperatingMode = {parameter_number = 10, size = 1},
      ch1ReactionToSwitch = {parameter_number = 11, size = 1},
      ch1TimerParameter = {parameter_number = 12, size = 2},
      ch1PulseTime = {parameter_number = 13, size = 2},
      ch2OperatingMode = {parameter_number = 15, size = 1},
      ch2ReactionToSwitch = {parameter_number = 16, size = 1},
      ch2TimeParameter = {parameter_number = 17, size = 2},
      ch2PulseTime = {parameter_number = 18, size = 1},
      switchType = {parameter_number = 20, size = 1},
      flashingReports = {parameter_number = 21, size = 1},
      s1ScenesSent = {parameter_number = 28, size = 1},
      s2ScenesSent = {parameter_number = 29, size = 1},
      ch1EnergyReports = {parameter_number = 53, size = 2},
      ch2EnergyReports = {parameter_number = 57, size = 2},
      periodicPowerReports = {parameter_number = 58, size = 2},
      periodicEnergyReports = {parameter_number = 59, size = 2}
    }
  },
  FIBARO_WALL_PLUG_US = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x1401,
      product_ids = {0x1001,0x2000}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 2, size = 1},
      overloadSafety = {parameter_number = 3, size = 2},
      standardPowerReports = {parameter_number = 11, size = 1},
      energyReportingThreshold = {parameter_number = 12, size = 2},
      periodicPowerReporting = {parameter_number = 13, size = 2},
      periodicReports = {parameter_number = 14, size = 2},
      ringColorOn = {parameter_number = 41, size = 1},
      ringColorOff = {parameter_number = 42, size = 1}
    }
  },
  FIBARO_WALL_PLUG_EU = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0602,
      product_ids = {0x1003, 0x1001}
    },
    PARAMETERS = {
      alwaysActive = {parameter_number = 1, size = 1},
      restoreState = {parameter_number = 2, size = 1},
      overloadSafety = {parameter_number = 3, size = 2},
      highPriorityPowerReport = {parameter_number = 10, size = 1},
      standardPowerReports = {parameter_number = 11, size = 1},
      powerReportFrequency = {parameter_number = 12, size = 2},
      energyReportingThreshold = {parameter_number = 13, size = 2},
      periodicReports = {parameter_number = 14, size = 2},
      ringColorOn = {parameter_number = 41, size = 1},
      ringColorOff = {parameter_number = 42, size = 1}
    }
  },
  FIBARO_WALL_PLUG_OLD_EU = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0600,
      product_ids = 0x1000
    },
    PARAMETERS = {
      alwaysActive = {parameter_number = 1, size = 1},
      restoreState = {parameter_number = 16, size = 1},
      overloadSafety = {parameter_number = 70, size = 2},
      inmediatePowerReport = {parameter_number = 40, size = 1},
      standardPowerReports = {parameter_number = 42, size = 1},
      powerReportFrequency = {parameter_number = 43, size = 1},
      energyReportingThreshold = {parameter_number = 45, size = 1},
      periodicReports = {parameter_number = 47, size = 2},
      ringColorOn = {parameter_number = 61, size = 1},
      ringColorOff = {parameter_number = 62, size = 1}
    }
  },
  FIBARO_SINGLE = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0403,
      product_ids = {0x1000, 0x2000, 0x3000}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 9, size = 1},
      ch1OperatingMode = {parameter_number = 10, size = 1},
      ch1ReactionToSwitch = {parameter_number = 11, size = 1},
      ch1TimeParameter = {parameter_number = 12, size = 2},
      ch1PulseTime = {parameter_number = 13, size = 2},
      switchType = {parameter_number = 20, size = 1},
      flashingReports = {parameter_number = 21, size = 1},
      s1ScenesSent = {parameter_number = 28, size = 1},
      s2ScenesSent = {parameter_number = 29, size = 1},
      ch1EnergyReports = {parameter_number = 53, size = 2},
      periodicPowerReports = {parameter_number = 58, size = 2},
      periodicEnergyReports = {parameter_number = 59, size = 2}
    }
  },
  FIBARO_RELAY_SINGLE = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0402,
      product_ids = {0x1002}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 16, size = 1},
      autoOffRelay = {parameter_number = 3, size = 1},
      autoOffTime = {parameter_number = 4, size = 2},
      bistableKeyStatus = {parameter_number = 13, size = 1},
      switchType = {parameter_number = 14, size = 1},
      dimmerRollerShutter = {parameter_number = 15, size = 1},
    }
  },
  FIBARO_SMART_MODULE_SINGLE = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0404,
      product_ids =  {0x1000, 0X2000, 0X3000}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 1, size = 1},
      switchType = {parameter_number = 20, size = 1},
      inputOrientation = {parameter_number = 24, size = 1},
      outputOrientation = {parameter_number = 25, size = 1},
      s1ScenesSent = {parameter_number = 40, size = 1},
      s2ScenesSent = {parameter_number = 41, size = 1},
      ch1OperatingMode = {parameter_number = 150, size = 1},
      ch1ReactionToSwitch = {parameter_number = 152, size = 1},
      ch1TimeParameter = {parameter_number = 154, size = 2},
      outputTypeQ1 = {parameter_number = 162, size = 1},
    }
  },
  FIBARO_RELAY_DUAL = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = {0x0202,0x0200},
      product_ids = {0x1002, 0x100A}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 16, size = 1},
      autoOffRelay = {parameter_number = 3, size = 1},
      autoOffTime1 = {parameter_number = 4, size = 2},
      autoOffTime2 = {parameter_number = 5, size = 2},
      bistableKeyStatus = {parameter_number = 13, size = 1},
      switchType = {parameter_number = 14, size = 1},
      dimmerRollerShutter = {parameter_number = 15, size = 1},
    }
  },
  FIBARO_SMART_MODULE_DOUBLE = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0204,
      product_ids = {0x1000, 0X2000, 0X3000}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 1, size = 1},
      switchType = {parameter_number = 20, size = 1},
      switchType2 = {parameter_number = 21, size = 1},
      inputOrientation = {parameter_number = 24, size = 1},
      outputOrientation = {parameter_number = 25, size = 1},
      s1ScenesSent = {parameter_number = 40, size = 1},
      s2ScenesSent = {parameter_number = 41, size = 1},
      ch1OperatingMode = {parameter_number = 150, size = 1},
      ch2OperatingMode = {parameter_number = 151, size = 1},
      ch1ReactionToSwitch = {parameter_number = 152, size = 1},
      ch2ReactionToSwitch = {parameter_number = 153, size = 1},
      ch1TimeParameter = {parameter_number = 154, size = 2},
      ch2TimeParameter = {parameter_number = 155, size = 2},
      outputTypeQ1 = {parameter_number = 162, size = 1},
      outputTypeQ2 = {parameter_number = 163, size = 1},
    }
  },
  FIBARO_DIMMER_2 = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0102,
      product_ids = {0x1000, 0x1001, 0x2000, 0x3000}
    },
    PARAMETERS = {
      minimumLevel = {parameter_number = 1, size = 1},
      maximumLevel = {parameter_number = 2, size = 1},
      restoreState = {parameter_number = 9, size = 1},
      autoOffTimer = {parameter_number = 10, size = 2},
      autoCalibration = {parameter_number = 13, size = 1},
      forcedOnLevel = {parameter_number = 19, size = 1},
      switchType = {parameter_number = 20, size = 1},
      toggleSwitchStatus = {parameter_number = 22, size = 1},
      doubleClickOption = {parameter_number = 23, size = 1},
      threeWaySwitch = {parameter_number = 26, size = 1},
      sceneActivation = {parameter_number = 28, size = 1},
      onOffMode = {parameter_number = 32, size = 1},
      activePowerReports = {parameter_number = 50, size = 2},
      periodicPowerReports = {parameter_number = 52, size = 2},
      energyReports = {parameter_number = 53, size = 2}
    }
  },
  FIBARO_DIMMER_1 = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = {0x0000, 0x0100},
      product_ids = {0x100A, 0x0109}
    },
    PARAMETERS = {
      minimumLevel = {parameter_number = 13, size = 1},
      maximumLevel = {parameter_number = 12, size = 1},
      restoreState = {parameter_number = 16, size = 1},
      switchType = {parameter_number = 14, size = 1},
      toggleSwitchStatus = {parameter_number = 19, size = 1},
      doubleClickOption = {parameter_number = 15, size = 1},
      threeWaySwitch = {parameter_number = 17, size = 1},
    }
  },
  AEOTEC_NANO_DIMMER = {
    MATCHING_MATRIX = {
      mfrs = 0x0086,
      product_types = {0x0003, 0x0103, 0x0203},
      product_ids = 0x006F
    },
    PARAMETERS = {
      minimumDimmingValue = {parameter_number = 131, size = 1}
    }
  },
  ZOOZ_ZEN_30 = {
    MATCHING_MATRIX = {
      mfrs = 0x027A,
      product_types = 0xA000,
      product_ids = 0xA008
    },
    PARAMETERS = {
      powerFailure = {parameter_number = 12, size = 1},
      ledSceneControl = {parameter_number = 7, size = 1},
      relayLedMode = {parameter_number = 2, size = 1},
      relayLedColor = {parameter_number = 4, size = 1},
      relayLedBrightness = {parameter_number = 6, size = 1},
      relayAutoOff = {parameter_number = 10, size = 4},
      relayAutoOn = {parameter_number = 11, size = 4},
      relayLoadControl = {parameter_number = 20, size = 1},
      relayPhysicalDisabledBeh = {parameter_number = 25, size = 1},
      dimmerLedMode = {parameter_number = 1, size = 1},
      dimmerLedColor = {parameter_number = 3, size = 1},
      dimmerLedBright = {parameter_number = 5, size = 1},
      dimmerAutoOff = {parameter_number = 8, size = 4},
      dimmerAutoOn = {parameter_number = 9, size = 4},
      dimmerRampRate = {parameter_number = 13, size = 1},
      dimmerPaddleRamp = {parameter_number = 21, size = 1},
      dimmerMinimumBright = {parameter_number = 14, size = 1},
      dimmerMaximumBright = {parameter_number = 15, size = 1},
      dimmerCustomBright = {parameter_number = 23, size = 1},
      dimmerBrightControl = {parameter_number = 18, size = 1},
      dimmerDoubleTapFunc = {parameter_number = 17, size = 1},
      dimmerLoadControl = {parameter_number = 19, size = 1},
      dimmerPhysDisBeh = {parameter_number = 24, size = 1},
      dimmerNightBright = {parameter_number = 26, size = 1},
      dimmerPaddleControl = {parameter_number = 27, size = 1}
    }
  },
  SWITCH_LEVEL_INDICATOR = {
    MATCHING_MATRIX = {
      mfrs = 0x0063,
      product_types = {0x4457, 0x4944, 0x5044}
    },
    PARAMETERS = {
      ledIndicator = {parameter_number = 3, size = 1}
    }
  },
  SWITCH_BINARY_INDICATOR = {
    MATCHING_MATRIX = {
      mfrs = {0x0063, 0113},
      product_types = {0x4952, 0x5257, 0x5052, 5257}
    },
    PARAMETERS = {
      ledIndicator = {parameter_number = 3, size = 1}
    }
  }
}


local preferences = {}

--- Handle preference changes
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param event table
--- @param args
function preferences.info_changed(driver, device, args)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    --local preferences = preferencesMap.get_device_parameters(device)
    local prefs = preferences.get_device_parameters(device)
    for id, value in pairs(device.preferences) do

      --local oldPreferenceValue = device:get_field(id)
      local oldPreferenceValue = args.old_st_store.preferences[id]
      local newParameterValue = device.preferences[id]

      if prefs ~= nil then
        print("<<< args", args)
        if args.old_st_store.preferences[id] ~= value and prefs and prefs[id] then
          print("Preference Changed >>>", id,"Old Value >>>>>>>>>",args.old_st_store.preferences[id], "Value >>", value)
          local new_parameter_value = preferences.to_numeric_value(device.preferences[id])
          print(">>>>> parameter_number:",prefs[id].parameter_number,"size:",prefs[id].size,"configuration_value:",new_parameter_value)
          --2's complement value if needed
          if prefs[id].size == 4 and new_parameter_value > 2147483647 then
            new_parameter_value = new_parameter_value - 4294967296
          elseif prefs[id].size == 2 and new_parameter_value > 32767 then
            new_parameter_value = new_parameter_value - 65536
          elseif prefs[id].size == 1 and new_parameter_value > 127 then
            new_parameter_value = new_parameter_value - 256
          end
          print("new_parameter_value Sent >>>>",new_parameter_value)
          device:send(Configuration:Set({parameter_number = prefs[id].parameter_number, size = prefs[id].size, configuration_value = new_parameter_value}))
        end
      end
      --change profile tile
      if oldPreferenceValue ~= newParameterValue then
          --device:set_field(id, newParameterValue, {persist = true})
        if id == "changeProfileDualSwitch" then
          if device.preferences.changeProfileDualSwitch == "Single" then
            device:try_update_metadata({profile = "dual-switch"})
          elseif device.preferences.changeProfileDualSwitch == "Multi" then
            device:try_update_metadata({profile = "dual-switch-multi"})
          end
        elseif id == "changeProfileDualPlug" then
          if device.preferences.changeProfileDualPlug == "Single" then
            device:try_update_metadata({profile = "smartplug-switch-2"})
          elseif device.preferences.changeProfileDualPlug == "Multi" then
            device:try_update_metadata({profile = "smartplug-switch-2-multi"})
          end
        elseif id == "changeProfileDualMetSw" then
          if device.preferences.changeProfileDualMetSw == "Single" then
            device:try_update_metadata({profile = "dual-metering-switch"})
          elseif device.preferences.changeProfileDualMet == "Multi" then
            device:try_update_metadata({profile = "dual-metering-switch-multi"})
          end
        elseif id == "changeProfileFibaroSW" then    -- fibaro double switch
          if device.preferences.changeProfileFibaroSW == "Single" then
            device:try_update_metadata({profile = "switch-1-button-2-power-energy"}) -- fibaro double switch
          elseif device.preferences.changeProfileFibaroSW == "Multi" then
            device:try_update_metadata({profile = "switch-1-button-2-power-energy-multi"}) -- fibaro double switch
          end
        elseif id == "changeProfileWally" then    -- fibaro double switch
          if device.preferences.changeProfileWally == "Single" then
            device:try_update_metadata({profile = "fibaro-walli-double-switch"}) -- fibaro wally double switch
          elseif device.preferences.changeProfileWally == "Multi" then
            device:try_update_metadata({profile = "fibaro-walli-double-switch-multi"}) -- fibaro wally double switch
          end
        elseif id == "changeProfileFibRelay" then    -- fibaro double relay
          if device.preferences.changeProfileFibRelay == "Single" then
            device:try_update_metadata({profile = "fibaro-relay-dual"}) -- fibaro double relay
          elseif device.preferences.changeProfileFibRelay == "Multi" then
            device:try_update_metadata({profile = "fibaro-relay-dual-multi"}) -- fibaro double relay
          end
        elseif id == "changeProfileFibSmart" then    -- fibaro double smart relay
          if device.preferences.changeProfileFibRelay == "Single" then
            device:try_update_metadata({profile = "fibaro-smart-relay-double"}) -- fibaro double smart relay
          elseif device.preferences.changeProfileFibRelay == "Multi" then
            device:try_update_metadata({profile = "fibaro-smart-relay-double-multi"}) -- fibaro double smart relay
          end
        elseif id == "changeProfileThreeSwitch" then
          if device.preferences.changeProfileThreeSwitch == "Single" then
            device:try_update_metadata({profile = "switch-multicomponent-3"})
          elseif device.preferences.changeProfileThreeSwitch == "Multi" then
            device:try_update_metadata({profile = "switch-multicomponent-3-multi"})
          end
        elseif id == "changeProfileFourSwitch" then
          if device.preferences.changeProfileFourSwitch == "Single" then
            device:try_update_metadata({profile = "switch-multicomponent-4"})
          elseif device.preferences.changeProfileFourSwitch == "Multi" then
            device:try_update_metadata({profile = "switch-multicomponent-4-multi"})
          end
        elseif id == "changeProfileOneMP" then
          if device.preferences.changeProfileFourSwitch == "Single" then
            device:try_update_metadata({profile = "metering-plug"})
          elseif device.preferences.changeProfileFourSwitch == "Multi" then
            device:try_update_metadata({profile = "metering-plug-multi"})
          end

        ----- create hild deives if request ------
        elseif id == "switch1Child" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new(driver, device, "switch1", "child-switch")
          end     
        elseif id == "switch2Child" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new(driver, device, "switch2", "child-switch")
          end  
        elseif id == "switch3Child" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
            child_devices.create_new(driver, device, "switch3", "child-switch")
          end
        elseif id == "switch4Child" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
            child_devices.create_new(driver, device, "switch4", "child-switch")
          end
        elseif id == "switch5Child" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
            child_devices.create_new(driver, device, "switch5", "child-switch")
          end
        elseif id == "configChild" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
            child_devices.create_new(driver, device, "main", "zwave-device-info")
          end
        end
      end
    end
    -- This will print in the log the total memory in use by Lua in Kbytes
    print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
  end
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