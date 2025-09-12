local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local Basic = (require "st.zwave.CommandClass.Basic")({ version=1 })

local ECOLINK_FINGERPRINTS = {
  {mfr = 0x014A, prod = 0x0006, model = 0x0002},
  {mfr = 0x014A, prod = 0x0006, model = 0x0003},
  {mfr = 0x014A, prod = 0x0006, model = 0x0004},
  {mfr = 0x014A, prod = 0x0006, model = 0x0005},
  {mfr = 0x014A, prod = 0x0006, model = 0x0006}
}

local function can_handle_ecolink(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(ECOLINK_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("ecolink-switch")
      return true, subdriver
    end
  end
  return false
end

local function basic_set_handler(driver, device, cmd)
  if cmd.args.value == 0xFF then
    device:emit_event(capabilities.switch.switch.on())
  else
    device:emit_event(capabilities.switch.switch.off())
  end
end

local ecolink_switch = {
  NAME = "Ecolink Switch",
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.SET] = basic_set_handler
    }
  },
  can_handle = can_handle_ecolink
}

return ecolink_switch