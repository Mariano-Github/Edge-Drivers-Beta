
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
     local subdriver = require("battery")
    if device:get_manufacturer() == "_TZ2000_a476raq2" then
      return true, subdriver
    elseif device:get_manufacturer() == "CentraLite" then
      return true, subdriver
    elseif device:get_manufacturer() == "iMagic by GreatStar" then
      return true, subdriver
    elseif device:get_manufacturer() == "SmartThings" then
      return true, subdriver
    elseif device:get_manufacturer() == "Bosch" then
      return true, subdriver
    elseif device:get_manufacturer() == "Samjin" and device:get_model() == "button" then
      return true, subdriver
    end
    subdriver = nil
    return false
end