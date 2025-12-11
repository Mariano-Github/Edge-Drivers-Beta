
-- Licensed under the Apache License, Version 2.0



local ZIGBEE_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "ORVIBO", model = "895a2d80097f4ae2b2d40500d5e03dcc", timeout = 20 },
  { mfr = "Megaman", model = "PS601/z1", timeout = 20 },
  { mfr = "HEIMAN", model = "PIRSensor-N", timeout = 20 },
  { mfr = "HiveHome.com", model = "MOT003", timeout = 20 },
  { mfr = "_TYZB01_3zv6oleo", model = "TS0210", timeout = 30 },
  { mfr = "_TZ3000_mcxw5ehu", model = "TS0202", timeout = 30 },
  { mfr = "lk", model = "ZB-MotionSensor-D0003", timeout = 20 },
  { mfr = "Konke", model = "3AFE28010402000D", timeout = 30 },
  { mfr = "TCL", model = "MS01", timeout = 30 },
  {mfr = "_TZ3000_fkxmyics", model = "TS0210", timeout = 30 },
  {mfr = "_TZ3000_lzdjjfss", model = "TS0210", timeout = 30 },
}

return function(opts, driver, device, ...)

   if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_MOTION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("motion_timeout")
          return true, subdriver
        end
    end
  end
  return false
end