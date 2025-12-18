
-- Licensed under the Apache License, Version 2.0

local NAMROM_THERMOSTAT_FINGERPRINTS = {
  { mfr = "Namron AS", model = "4512758" }, -- white color
  { mfr = "Namron AS", model = "4512759" }, -- black color
  { mfr = "Namron AS", model = "4512783" } -- black color
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(NAMROM_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("namrom-thermostat-Hvit")
      return true, subdriver
    end
  end
  return false
end