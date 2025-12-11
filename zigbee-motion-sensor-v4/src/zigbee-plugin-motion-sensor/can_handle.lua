
-- Licensed under the Apache License, Version 2.0


local ZIGBEE_PLUGIN_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "eZEX", model = "E280-KR0A0Z0-HA" },
  { mfr = "LUMI", model = "lumi.sensor_motion.aq2" }
}
return function(opts, driver, device, ...)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_PLUGIN_MOTION_SENSOR_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        local subdriver = require("zigbee-plugin-motion-sensor")
          return true, subdriver
      end
    end
  end
  return false
end