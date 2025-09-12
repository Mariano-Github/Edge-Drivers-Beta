local devices = {
  TKB_RGBW_CONROLLER = {
    MATCHING_MATRIX = {
      mfrs = 0x0118,
      product_types = 0x0311,
      product_ids = 0x0302
    },
    PARAMETERS = {
      indicatorState = {parameter_number = 1, size = 1},
      restoreState = {parameter_number = 2, size = 1},
    }
  },
  FIBARO_RGBW_CONROLLER = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0900,
      product_ids = {0x1000, 0x2000}
    },
    PARAMETERS = {
      alOnAllOffActivation = {parameter_number = 1, size = 1},
      associationsCommand = {parameter_number = 6, size = 1},
      outputsStateMode = {parameter_number = 8, size = 1},
      stepValue = {parameter_number = 9, size = 1},
      timeBetweenSteps = {parameter_number = 10, size = 2},
      timeChangingStartEnd = {parameter_number = 11, size = 1},
      maximumBrightening = {parameter_number = 12, size = 1},
      minimumDim = {parameter_number = 13, size = 1},
      inputsOutputsConfig1 = {parameter_number = 14, size = 2},
      inputsOutputsConfig2 = {parameter_number = 14, size = 2},
      inputsOutputsConfig3 = {parameter_number = 14, size = 2},
      inputsOutputsConfig4 = {parameter_number = 14, size = 2},
      restoreState = {parameter_number = 16, size = 1},
      alarmAnyType = {parameter_number = 30, size = 1},
      alarmProgram = {parameter_number = 38, size = 1},
      alarmTime = {parameter_number = 39, size = 2},
      commandClassOutputs = {parameter_number = 42, size = 1},
      analogInputsThreshold = {parameter_number = 43, size = 1},
      powerReportingFrequency = {parameter_number = 44, size = 2},
      reportingChangesEnergy = {parameter_number = 45, size = 1},
      responseBrightness0 = {parameter_number = 71, size = 1},
      --animationProgramNumber = {parameter_number = 72, size = 1},
      tripleClickAction = {parameter_number = 73, size = 1}
    }
  },
  FIBARO_RGBW_CONROLLER_2 = {
    MATCHING_MATRIX = {
      mfrs = {0x010F,0x027A},
      product_types = 0x0902,
      product_ids = {0x1000, 0x2000, 0x3000}
    },
    PARAMETERS = {
      restoreState = {parameter_number = 1, size = 1},
      inputConfig1 = {parameter_number = 20, size = 1},
      inputConfig2 = {parameter_number = 21, size = 1},
      inputsConfig3 = {parameter_number = 22, size = 1},
      inputConfig4 = {parameter_number = 23, size = 1},
      inp1ScenesSent = {parameter_number = 40, size = 1},
      inp2ScenesSent = {parameter_number = 41, size = 1},
      inp3ScenesSent = {parameter_number = 42, size = 1},
      inp4ScenesSent = {parameter_number = 43, size = 1},
      powerReportingFrequency = {parameter_number = 62, size = 2},
      analogInputsThreshold = {parameter_number = 63, size = 2},
      analogInputsReports = {parameter_number = 64, size = 2},
      reportingChangesEnergy = {parameter_number = 65, size = 2},
      energyReportingFrequency = {parameter_number = 66, size = 2},
      inputsColorMode = {parameter_number = 150, size = 1},
      localTransitionTime = {parameter_number = 151, size = 2},
      remoteTransitionTime = {parameter_number = 152, size = 2},
      --programmedSecuence = {parameter_number = 157, size = 1},
    }
  }
}

local preferences = {}

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