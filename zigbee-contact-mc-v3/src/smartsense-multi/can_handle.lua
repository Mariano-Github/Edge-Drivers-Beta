
-- Licensed under the Apache License, Version 2.0

local SMARTSENSE_MULTI_FINGERPRINTS = {
  { mfr = "SmartThings", model = "PGC313" },
  { mfr = "SmartThings", model = "PGC313EU" }
}

return function(opts, driver, device, ...)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(SMARTSENSE_MULTI_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        --print("<< SmartSense-multi subdriver >>")
        local subdriver = require("smartsense-multi")
      return true, subdriver
      end
    end
    --print("device.zigbee_endpoints[1].profileId",device.zigbee_endpoints[1].profileId)
    --if device.zigbee_endpoints[1].profileId ~= nil then
      --if device.zigbee_endpoints[1].profileId == SMARTSENSE_PROFILE_ID then return true end
    --end
  end
  return false
end
