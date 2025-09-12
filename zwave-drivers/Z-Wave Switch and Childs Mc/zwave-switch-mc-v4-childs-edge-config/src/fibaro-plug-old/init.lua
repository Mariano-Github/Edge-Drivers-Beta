local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local Basic = (require "st.zwave.CommandClass.Basic")({ version=1 })
--- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({version=3})
--- @type st.zwave.constants
--local constants = require "st.zwave.constants"

local FIBARO_PLUG_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0600, model = 0x1000}, -- fibaro plug old
}

local function can_handle_fibaro_plug_old(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(FIBARO_PLUG_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("fibaro-plug-old")
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
  local query_device = function()
    device:send(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS},{dst_channels = {cmd.src_channel}}))
    device:send(Meter:Get({scale = Meter.scale.electric_meter.WATTS},{dst_channels = {cmd.src_channel}}))
  end
   device.thread:call_with_delay(4, query_device)
end

local fibaro_plug = {
  NAME = "Fibaro Plug Old",
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.SET] = basic_set_handler
    }
  },
  can_handle = can_handle_fibaro_plug_old
}

return fibaro_plug