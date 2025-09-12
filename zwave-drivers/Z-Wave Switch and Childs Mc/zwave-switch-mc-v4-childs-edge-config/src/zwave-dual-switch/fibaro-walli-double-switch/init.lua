local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=2,strict=true})
--- @type st.zwave.CommandClass.Meter
--local Meter = (require "st.zwave.CommandClass.Meter")({version=3})

--local child_devices = require "child-devices"

local FIBARO_WALLI_DOUBLE_SWITCH_FINGERPRINT = {mfr = 0x010F, prod = 0x1B01, model = 0x1000}

local function can_handle_fibaro_walli_double_switch(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
    if device:id_match(FIBARO_WALLI_DOUBLE_SWITCH_FINGERPRINT.mfr, FIBARO_WALLI_DOUBLE_SWITCH_FINGERPRINT.prod, FIBARO_WALLI_DOUBLE_SWITCH_FINGERPRINT.model) then
      return true
    end
  return false
end

local function endpoint_to_component(device, endpoint)
  if endpoint == 2 then
    return "switch1"
  else
    return "main"
  end
end

local function component_to_endpoint(device, component)
  if component == "switch1" then
    return {2}
  else
    return {1}
  end
end

local function map_components(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:set_endpoint_to_component_fn(endpoint_to_component)
    device:set_component_to_endpoint_fn(component_to_endpoint)
  end
end

---zwave_handlers_report
local function zwave_handlers_report(driver, device, cmd)
  print("<<<<< zwave_handlers_report in Sub driver >>>>>>>")
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
  print("cmd.src_channel >>>>>>",cmd.src_channel)
  local component= endpoint_to_component(device, cmd.src_channel)
  local child_device = device:get_child_by_parent_assigned_key(component)
  if child_device ~= nil then
    child_device:emit_event(event)
  end
end

local fibaro_walli_double_switch = {
  NAME = "fibaro walli double switch",
  lifecycle_handlers = {
    init = map_components
  },
  zwave_handlers = {
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = zwave_handlers_report
    },
  },
  can_handle = can_handle_fibaro_walli_double_switch,
}

return fibaro_walli_double_switch
