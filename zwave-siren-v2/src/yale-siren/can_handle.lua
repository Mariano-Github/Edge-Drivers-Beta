
-- Licensed under the Apache License, Version 2.0

local YALE_MFR = 0x0129

return function(opts, driver, device, ...)
  if device.zwave_manufacturer_id == YALE_MFR then
    local subdriver = require("yale-siren")
    return true, subdriver
  end
end