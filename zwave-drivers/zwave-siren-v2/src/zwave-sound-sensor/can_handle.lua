
-- Licensed under the Apache License, Version 2.0

local ZWAVE_SOUND_SENSOR_FINGERPRINTS = {
  { manufacturerId = 0x014A, productType = 0x0005, productId = 0x000F } --Ecolink Firefighter
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(ZWAVE_SOUND_SENSOR_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("zwave-sound-sensor")
      return true, subdriver
    end
  end
  return false
end