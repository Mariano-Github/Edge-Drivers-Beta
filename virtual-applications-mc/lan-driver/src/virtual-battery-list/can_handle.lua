
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)

   if device.preferences.switchNumber == 11 then
      local subdriver = require("virtual-battery-list")
      return true, subdriver
    else
      return false
    end
  end