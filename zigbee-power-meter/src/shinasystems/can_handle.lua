
-- Licensed under the Apache License, Version 2.0

local ZIGBEE_POWER_METER_FINGERPRINTS = {
  { model = "PMM-300Z1" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(ZIGBEE_POWER_METER_FINGERPRINTS) do
      if device:get_model() == fingerprint.model then
        local subdriver = require("shinasystems")
        return true, subdriver
      end
  end

  return false
end
