
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    if device:get_model() == "SMOK_V16" or 
      device:get_model() == "SmokeSensor-N" or
      device:get_model() == "SmokeSensor-N-3.0" or
      device:get_model() == "SMOK_YDLV10" or
      device:get_model() == "COSensor-EM" or
      (device:get_model() == "TS0205" and device:get_manufacturer() == "_TYZB01_wqcac7lo") or
      (device:get_model() == "TS0205" and device:get_manufacturer() == "_TZ3210_up3pngle") or
      (device:get_model() == "TS0205" and device:get_manufacturer() == "_TYZB01_dsjszp0x") or
      device:get_model() == "TS0205" then
        local subdriver = require("heiman-SMOK_V16")
        return true, subdriver
    end
  end
  return false
end