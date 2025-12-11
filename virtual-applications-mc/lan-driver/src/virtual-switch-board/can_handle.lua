
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)

  if device.preferences.switchNumber > 1 and  device.preferences.switchNumber < 6 then
    local subdriver = require("virtual-switch-board")
    return true, subdriver
  else
    return false
  end  
end