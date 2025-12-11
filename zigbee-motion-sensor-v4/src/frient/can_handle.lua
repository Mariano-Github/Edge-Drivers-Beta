
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)
local ZIGBEE_FRIENT_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "frient A/S", model = "MOSZB-140" },
  { mfr = "Develco Products A/S", model = "MOSZB-140" },
  { mfr = "Develco Products A/S", model = "MOSZB-130" },
}

  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_FRIENT_MOTION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("frient")
          return true, subdriver
        end
    end
  end
  return false
end