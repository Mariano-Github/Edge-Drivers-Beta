
-- Licensed under the Apache License, Version 2.0

local ZIPATO_MFR = 0x0131

return function(opts, driver, device, ...)
  if device.zwave_manufacturer_id == ZIPATO_MFR then
    local subdriver = require("zipato-siren")
    return true, subdriver

  end
end