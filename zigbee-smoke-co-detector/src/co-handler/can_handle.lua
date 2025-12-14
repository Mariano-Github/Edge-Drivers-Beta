
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    if (device:get_manufacturer() == "feibit" and device:get_model() == "FNB56-COS06FB1.7")
      or (device:get_manufacturer() == "HEIMAN" and device:get_model() == "COSensor-EF-3.0")
      or (device:get_manufacturer() == "Heiman" and device:get_model() == "CO_V16")
      or (device:get_manufacturer() == "Trust" and device:get_model() == "COSensor-EM")
      or (device:get_manufacturer() == "_TYZB01_18pkine6" and device:get_model() == "TS0204")
      or (device:get_manufacturer() == "_TYZB01_wpmo3ja3" and device:get_model() == "TS0212")
      or (device:get_manufacturer() == "_TYZB01_o7m83470" and device:get_model() == "TS0212")
      or (device:get_manufacturer() == "Heiman" and device:get_model() == "1ccaa94c49a84abaa9e38687913947ba")
      or (device:get_model() == "TS0212") then
        local subdriver = require("co-handler")
        return true, subdriver
    end
  end
  return false
end