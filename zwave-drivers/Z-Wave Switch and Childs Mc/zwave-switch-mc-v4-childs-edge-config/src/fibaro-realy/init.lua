local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local Basic = (require "st.zwave.CommandClass.Basic")({ version=1 })

local FIBARO_RELAY_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0402, model = 0x1002},
  --{mfr = 0x010F, prod = 0x0202, model = 0x1002}, -- fibaro relay double
}

local function can_handle_fibaro_relay(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(FIBARO_RELAY_FINGERPRINTS) do
    --if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
    if device:id_match(fingerprint.mfr, fingerprint.prod) then
      local subdriver = require("fibaro-realy")
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

local fibaro_relay = {
  NAME = "Fibaro Relay",
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.SET] = basic_set_handler
    }
  },
  can_handle = can_handle_fibaro_relay
}

return fibaro_relay