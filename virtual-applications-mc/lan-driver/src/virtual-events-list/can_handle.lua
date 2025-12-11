
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)

        if device.preferences.switchNumber == 12 then
      local subdriver = require("virtual-events-list")
      return true, subdriver
    else
      return false
    end  
  end