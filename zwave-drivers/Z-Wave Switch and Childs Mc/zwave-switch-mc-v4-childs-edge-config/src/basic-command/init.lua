local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local Basic = (require "st.zwave.CommandClass.Basic")({ version=1 })
--- @type st.zwave.CommandClass.SwitchMultilevel
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({version=4,strict=true})
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.utils
local utils = require "st.utils"

local DEVICES_FINGERPRINTS = {
  {mfr = 0x0118, prod = 0x0311, model = 0x0201}, -- -- TKB Home TZ55S Plus Dimmer
  {mfr = 0xFFFF, prod = 0x0003, model = 0x0004}, -- -- TKB Home TZ55S Plus Dimmer
}

local function can_handle_basic_command(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(DEVICES_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("basic-command")
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

--- send on-off command
local function switch_set_helper(driver, device, value, command)
  print("<<<<< switch_set_helper in main driver >>>>>>>")
  local set
  local get
  --print("<<<<< device.ID >>>>>", device.id)
  --print("<<<<<< value >>>>>>",value)
  local delay = constants.DEFAULT_GET_STATUS_DELAY
  
    -- log.trace_with({ hub_logs = true }, "SWITCH_BINARY and SWITCH_MULTILEVEL NOT supported. Use Basic.Set()")
  set = Basic:Set({
    value = value
  })
  get = Basic:Get({})

  device:send_to_component(set, command.component)
  local query_device = function()
    device:send_to_component(get, command.component)
    device:send_to_component(SwitchMultilevel:Get({}), command.component)
  end
  device.thread:call_with_delay(delay, query_device)
end

--- switch_on_handler
local function switch_on_handler(driver, device, command)
  print("<<<<< switch_on_handler in main driver >>>>>>>")
  switch_set_helper(driver, device, 255, command)
end

--- switch_off_handler
local function switch_off_handler(driver,device,command)
  print("<<<<< switch_off_handler in main driver >>>>>>>")
  switch_set_helper(driver, device, 0, command)
end

--- switch_level_handler
local function switch_level_handler(driver,device,command)
  print("<<<<< switch_level_handler in main driver >>>>>>>")
  local level = utils.round(command.args.level)
  level = utils.clamp_value(level, 1, 99)
  switch_set_helper(driver, device, level, command)
end

local basic_command = {
  NAME = "Basic Command",
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_on_handler,
      [capabilities.switch.commands.off.NAME] = switch_off_handler
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = switch_level_handler
    }
  },
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.SET] = basic_set_handler
    }
  },
  lifecycle_handlers = {

  },
  can_handle = can_handle_basic_command,
}

return basic_command
