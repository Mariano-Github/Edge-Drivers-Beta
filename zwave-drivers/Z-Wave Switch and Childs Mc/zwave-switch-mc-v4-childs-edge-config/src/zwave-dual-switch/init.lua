local capabilities = require "st.capabilities"
--- @type st.utils
--local utils = require "st.utils"
--- @type st.zwave.constants
--local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({ version = 1 })
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({ version = 2 })

local child_devices = require "child-devices"

local ZWAVE_DUAL_SWITCH_FINGERPRINTS = {
  {mfr = 0x0086, prod = 0x0103, model = 0x008C}, -- Aeotec Switch 1
  {mfr = 0x0086, prod = 0x0003, model = 0x008C}, -- Aeotec Switch 1
  {mfr = 0x0258, prod = 0x0003, model = 0x008B}, -- NEO Coolcam Switch 1
  {mfr = 0x0258, prod = 0x0003, model = 0x108B}, -- NEO Coolcam Switch 1
  {mfr = 0x0312, prod = 0xC000, model = 0xC004}, -- EVA Switch 1
  {mfr = 0x0312, prod = 0xFF00, model = 0xFF05}, -- Minoston Switch 1
  {mfr = 0x0312, prod = 0xC000, model = 0xC007}, -- Evalogik Switch 1
  {mfr = 0x010F, prod = 0x1B01, model = 0x1000},  -- Fibaro Walli Double Switch
  {mfr = 0x0299, prod = 0x0003, model = 0x1A91},  -- TechniSat ZM5101 Double-Switch
  --{ mfr = 0x027A, prod = 0xA000, model = 0xA003 }  -- Zooz Double Plug
  {mfr = 0x0118, prod = 0x0311, model = 0x0304}, -- added agosto 2023
  {mfr = 0x0298, prod = 0x13F1, model = 0x1405}, -- added agosto 2023
  {mfr = 0x0059, prod = 0x0003, model = 0x0002}, -- added agosto 2023
  {mfr = 0x0059, prod = 0x0003, model = 0x0006}, -- added dec 2024
  {mfr = 0x013C, prod = 0x0001, model = 0x0012}, -- added agosto 2023 Philio PAN04
  {mfr = 0x013C, prod = 0x0001, model = 0x0013}, -- added agosto 2023 Philio PAN06 (has 3 endpoints)
  {mfr = 0x015F, prod = 0x4121, model = 0x5102}, -- added sep 2023 MCO home dual switch
  {mfr = 0x011A, prod = 0x0101, model = 0x5606}, -- added sep 2023 Enerwavw RSM2 dual switch
  {mfr = 0x0086, prod = 0x0003, model = 0x0011}, -- Aeotec micro double
}

local function can_handle_zwave_dual_switch(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
    for _, fingerprint in ipairs(ZWAVE_DUAL_SWITCH_FINGERPRINTS) do
      if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
        local subdriver = require("zwave-dual-switch")
        return true, subdriver
      end
    end
  return false
end

local function endpoint_to_component(device, endpoint)
  if endpoint == 2 then
    return "switch1"
  else
    if device.zwave_manufacturer_id == 0x013C then
      if endpoint == 1 then
        return "main"
      end
    else
      return "main"
    end
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

local function device_added(driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:refresh()
  else
    child_devices.device_added(driver, device)
  end
end

---zwave_handlers_report
local function zwave_handlers_report(driver, device, cmd)
  print("<<<<< zwave_handlers_report in Sub driver >>>>>>>")
  if cmd.src_channel < 3 then
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
  else
    device:send_to_component(SwitchBinary:Get({}), "main")
    device:send_to_component(SwitchBinary:Get({}), "switch1")
  end
end

local function basic_set_handler(driver, device, cmd)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local value = cmd.args.target_value and cmd.args.target_value or cmd.args.value
    local event = value == 0x00 and capabilities.switch.switch.off() or capabilities.switch.switch.on()

    device:emit_event_for_endpoint(cmd.src_channel, event)

    -- emit event for childs devices
    print("cmd.src_channel >>>>>>",cmd.src_channel)
    local component= endpoint_to_component(device, cmd.src_channel)
    local child_device = device:get_child_by_parent_assigned_key(component)
    if child_device ~= nil and component ~= "main" then
      child_device:emit_event(event)
    end
  end
end

local zwave_dual_switch = {
  NAME = "zwave dual switch",
  capability_handlers = {
 
  },
  zwave_handlers = {
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = zwave_handlers_report
    },
    [cc.BASIC] = {
      [Basic.SET] = basic_set_handler,
      [Basic.REPORT] = zwave_handlers_report
    }
  },
  lifecycle_handlers = {
    init = map_components,
    added = device_added
  },
  can_handle = can_handle_zwave_dual_switch,
  sub_drivers = {
    --require("zwave-dual-switch/fibaro-walli-double-switch")
  }
}

return zwave_dual_switch
