local capabilities = require "st.capabilities"
--- @type st.utils
--local utils = require "st.utils"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.CentralScene
local CentralScene = (require "st.zwave.CommandClass.CentralScene")({version=1})
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=2,strict=true})
--- @type st.zwave.CommandClass.Meter
--local Meter = (require "st.zwave.CommandClass.Meter")({version=3})
--- @type st.zwave.CommandClass.Configuration
--local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })

local child_devices = require "child-devices"

local FIBARO_DOUBLE_SWITCH_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0203, model = 0x1000}, -- Fibaro double Switch FGS-223
  {mfr = 0x010F, prod = 0x0203, model = 0x2000}, -- Fibaro double Switch FGS-223
  {mfr = 0x010F, prod = 0x0203, model = 0x3000}, -- Fibaro double Switch FGS-223
  {mfr = 0x010F, prod = 0x0204, model = 0x1000}, -- Fibaro double Smart Relay FGS-224
  {mfr = 0x010F, prod = 0x0204, model = 0x2000}, -- Fibaro double Smart Relay FGS-224
  {mfr = 0x010F, prod = 0x0204, model = 0x3000}, -- Fibaro double Smart Relay FGS-224
}

local function can_handle_fibaro_double_switch(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
    for _, fingerprint in ipairs(FIBARO_DOUBLE_SWITCH_FINGERPRINTS) do
      if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
        local subdriver = require("fibaro-double-switch")
        return true, subdriver
      end
    end
  return false
end

local function central_scene_notification_handler(self, device, cmd)
  local map_key_attribute_to_capability = {
    [CentralScene.key_attributes.KEY_PRESSED_1_TIME] = capabilities.button.button.pushed,
    [CentralScene.key_attributes.KEY_RELEASED] = capabilities.button.button.held,
    [CentralScene.key_attributes.KEY_HELD_DOWN] = capabilities.button.button.down_hold,
    [CentralScene.key_attributes.KEY_PRESSED_2_TIMES] = capabilities.button.button.double,
    [CentralScene.key_attributes.KEY_PRESSED_3_TIMES] = capabilities.button.button.pushed_3x
  }

  local event = map_key_attribute_to_capability[cmd.args.key_attributes]
  local button_number = cmd.args.scene_number

  local component = device.profile.components["button" .. button_number]

  if component ~= nil then
    device:emit_component_event(component, event({state_change = true}))
  end
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

--- buttons 
local function do_added(driver,device)
  print("<<<<< device_added in subdriver >>>>>>>")
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:refresh()
    device.profile.components["button1"]:emit_event(capabilities.button.numberOfButtons({ value = 1 }, { visibility = { displayed = false }}))
    device.profile.components["button1"]:emit_event(capabilities.button.supportedButtonValues({"pushed", "held", "double", "down_hold", "pushed_3x"}, { visibility = { displayed = false }}))
    device.profile.components["button2"]:emit_event(capabilities.button.numberOfButtons({ value = 1 }, { visibility = { displayed = false }}))
    device.profile.components["button2"]:emit_event(capabilities.button.supportedButtonValues({"pushed", "held", "double", "down_hold", "pushed_3x"}, { visibility = { displayed = false }}))
    --device:emit_component_event("button1", capabilities.button.numberOfButtons({ value = 1 }, { visibility = { displayed = false }}))
    --device:emit_component_event("button1", capabilities.button.supportedButtonValues({"pushed", "held", "double", "down_hold", "pushed_3x"}, { visibility = { displayed = false }}))
    --device:emit_component_event("button2", capabilities.button.numberOfButtons({ value= 1 }, { visibility = { displayed = false }}))
    --device:emit_component_event("button2", capabilities.button.supportedButtonValues({"pushed", "held", "double", "down_hold", "pushed_3x"}, { visibility = { displayed = false }}))
  else
    child_devices.device_added(driver, device)
  end
end

local device_init = function(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<<< do_init in fibaro-double-switch subdriver >>>>")
    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)
  end
end

---on-off zwave_handlers_report
local function zwave_handlers_report(driver, device, cmd)
  print("<<<<< zwave_handlers_report in subdriver >>>>>>>")
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
  if child_device ~= nil and component ~= "main" then
    child_device:emit_event(event)
  end
end


local fibaro_double_switch = {
  NAME = "fibaro double switch",
  capability_handlers = {
    
  },
  zwave_handlers = {
    [cc.CENTRAL_SCENE] = {
      [CentralScene.NOTIFICATION] = central_scene_notification_handler
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = zwave_handlers_report
    }
  },
  lifecycle_handlers = {
    init = device_init,
    added = do_added,
  },
  can_handle = can_handle_fibaro_double_switch,
}

return fibaro_double_switch
