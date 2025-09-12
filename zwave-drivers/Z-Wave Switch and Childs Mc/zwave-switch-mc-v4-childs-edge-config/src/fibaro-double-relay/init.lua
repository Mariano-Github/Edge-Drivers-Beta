local capabilities = require "st.capabilities"
--- @type st.utils
--local utils = require "st.utils"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.CentralScene
--local CentralScene = (require "st.zwave.CommandClass.CentralScene")({version=1})
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({version=1,strict=true})
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=2,strict=true})

--local child_devices = require "child-devices"

local FIBARO_DOUBLE_RELAY_FINGERPRINTS = {
  --{mfr = 0x010F, prod = 0x0202, model = 0x1002}, -- fibaro relay double
  --{mfr = 0x010F, prod = 0x0200, model = 0x100A}, -- fibaro relay double
  {mfr = 0x010F, prod = 0x0202}, -- fibaro relay double fgs-222
  {mfr = 0x010F, prod = 0x0200}, -- fibaro relay double fgs-221
}

local function can_handle_fibaro_double_relay(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
    for _, fingerprint in ipairs(FIBARO_DOUBLE_RELAY_FINGERPRINTS) do
      --if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      if device:id_match(fingerprint.mfr, fingerprint.prod) then
        local subdriver = require("fibaro-double-relay")
        return true, subdriver
      end
    end
  return false
end


local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    return {1}
  else
    return {2}
  end
end

local function endpoint_to_component(device, ep)
  local switch_comp = string.format("switch%d", ep - 1)
  if device.profile.components[switch_comp] ~= nil then
    return switch_comp
  else
    return "main"
  end
end

local device_init = function(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)
  end

end

---zwave_handlers_report
local function zwave_handlers_report(driver, device, cmd)
  print("<<<<< zwave_handlers_report in main driver >>>>>>>")
  local event
  if cmd.args.target_value ~= nil then
    -- Target value is our best inidicator of eventual state.
    -- If we see this, it should be considered authoritative.
    if cmd.args.target_value == SwitchBinary.value.OFF_DISABLE then
      event = capabilities.switch.switch.off()
    else
      event = capabilities.switch.switch.on()
    end
  else
    if cmd.args.value == SwitchBinary.value.OFF_DISABLE then
      event = capabilities.switch.switch.off()
    else
      event = capabilities.switch.switch.on()
    end
  end
  device:emit_event_for_endpoint(cmd.src_channel, event)

  -- emit event for childs devices
  --print("cmd.src_channel >>>>>>",cmd.src_channel)
  local component= endpoint_to_component(device, cmd.src_channel)
  local child_device = device:get_child_by_parent_assigned_key(component)
  if child_device ~= nil and component ~= "main" then
    --  emit_event(capabilities.switch.switch.off() or on())
    child_device:emit_event(event)
  end
end

local fibaro_double_relay = {
  NAME = "fibaro double relay",
  capability_handlers = {

  },
  zwave_handlers = {
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = zwave_handlers_report
    },
    [cc.BASIC] = {
      [Basic.REPORT] = zwave_handlers_report
    },
    [cc.BASIC] = {
      [Basic.SET] = zwave_handlers_report
    }
  },
  lifecycle_handlers = {
    init = device_init
  },
  can_handle = can_handle_fibaro_double_relay,
}

return fibaro_double_relay
