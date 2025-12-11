
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)

   if device.preferences.switchNumber == 1 then
    local subdriver = require("virtual-mirror-switch")
    return true, subdriver
  else
    return false
  end  
end