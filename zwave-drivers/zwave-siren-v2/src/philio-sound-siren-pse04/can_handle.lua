
-- Licensed under the Apache License, Version 2.0

local PHILIO_SOUND_SIREN = {
  { manufacturerId = 0x013C, productType = 0x0004, productId = 0x0084 }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(PHILIO_SOUND_SIREN) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("philio-sound-siren-pse04")
      return true, subdriver
    end
  end
  return false
end