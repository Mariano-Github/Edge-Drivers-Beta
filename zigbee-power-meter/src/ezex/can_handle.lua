
-- Licensed under the Apache License, Version 2.0

local ZIGBEE_POWER_METER_FINGERPRINTS = {
  { model = "E240-KR080Z0-HA" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(ZIGBEE_POWER_METER_FINGERPRINTS) do
      if device:get_model() == fingerprint.model then
        local subdriver = require("ezex")
        return true, subdriver
      end
  end

  return false
end