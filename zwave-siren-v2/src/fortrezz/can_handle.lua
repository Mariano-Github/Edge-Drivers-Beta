
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)
  if device.zwave_manufacturer_id == 0x0084 and device.zwave_product_type == 0x0313 and device.zwave_product_id == 0x010B then
    local subdriver = require("fortrezz")
    return true, subdriver
end
end