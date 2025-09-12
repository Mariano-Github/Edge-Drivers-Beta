local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local Basic = (require "st.zwave.CommandClass.Basic")({ version=1 })

local FIBARO_DIMMER_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0100, model = 0x100A}, -- Fibaro Dimmer1
  {mfr = 0x010F, prod = 0x0100, model = 0x0109}, -- Fibaro Dimmer1
  {mfr = 0x010F, prod = 0x0000, model = 0x100A}, -- Fibaro Dimmer1
}

local function can_handle_fibaro_dimmer1(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(FIBARO_DIMMER_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("fibaro-dimmer1")
      return true, subdriver
    end
  end
  return false
end

local function basic_set_handler(driver, device, cmd)
    if cmd.args.value == 0xFF then
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.switch.switch.on())
    else
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.switch.switch.off())
    end
end

local fibaro_dimmer1 = {
  NAME = "fibaro dimmer1",
  capability_handlers = {
  },
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.SET] = basic_set_handler
    }
  },
  lifecycle_handlers = {

  },
  can_handle = can_handle_fibaro_dimmer1,
}

return fibaro_dimmer1
