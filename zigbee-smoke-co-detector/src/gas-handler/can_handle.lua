
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
  if device.preferences.changeProfile == "Gas" then
    --if (device:get_manufacturer() == "LUMI" and device:get_model() == "lumi.sensor_gas.acn02") or
      --(device:get_manufacturer() == "feibit" and device:get_model() == "FNB56-GAS05FB1.4") or
      --(device:get_manufacturer() == "_TYZB01_mfccmeio" and device:get_model() == "TS0204") or
      --(device:get_manufacturer() == "_TYZB01_0w3d5uw3" and device:get_model() == "TS0204") then -- gas detector
      local subdriver = require("gas-handler")
      return true, subdriver
    end
  end
  return false
end