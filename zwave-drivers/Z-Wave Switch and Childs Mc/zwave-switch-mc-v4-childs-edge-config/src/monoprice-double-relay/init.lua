local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({version=1,strict=true})
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=2,strict=true})
--- @type st.zwave.CommandClass.MultiChannel
local MultiChannel = (require "st.zwave.CommandClass.MultiChannel")({version=3})
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version=2 })
local Version = (require "st.zwave.CommandClass.Version")({ version = 2 })

--local child_devices = require "child-devices"
local multiChannel_end_point

local MONOPRICE_DOUBLE_RELAY_FINGERPRINTS = {
  {mfr = 0x0109, prod = 0x2017, model = 0x1717}, -- Monoprice relay double
}

local function can_handle_monoprice_double_relay(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
    for _, fingerprint in ipairs(MONOPRICE_DOUBLE_RELAY_FINGERPRINTS) do
      if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
        local subdriver = require("monoprice-double-relay")
        return true, subdriver
      end
    end
  return false
end


local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    if device:get_field("app_version") == "13.7" then
      return {1}
    else
      return {}
    end
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

local device_init = function(driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local _node_ids = {driver.environment_info.hub_zwave_id}
    device:send(Association:Set({grouping_identifier = 1, node_ids = _node_ids}))

    device:send(Version:Get({}))

    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)
  end
end

--multichannel_capability_report_handler
local function multichannel_capability_report_handler(driver, device, cmd)
  print("<<<<< multichannel_capability_report_handler >>>>>>>")
  --print("<<<<<<< cmd.args.end_point:",cmd.args.end_point)
  if device:get_field("app_version") == "13.7" then -- for monoprice old app version 
    multiChannel_end_point = cmd.args.end_point
  end
end

---zwave_handlers_report
local function zwave_handlers_report(driver, device, cmd)
  print("<<<<< zwave_handlers_report in sub driver >>>>>>>")
  print("<<<< cmd.src_channel",cmd.src_channel)
  if cmd.src_channel == 0 and device:get_field("app_version") == "13.7" then -- for monoprice old app version 
    cmd.src_channel = multiChannel_end_point
    local component = "main"
    if cmd.src_channel == 2 then component = "switch1" end
    device:send_to_component(SwitchBinary:Get({}), component)
    --device:send_to_component(SwitchBinary:Get({},{dst_channels = {cmd.src_channel}}))
    return
  end
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
    child_device:emit_event(event)
  end
  --device:send(Version:Get({}))
end

local function version_report_handler(driver, device, cmd)
  -- print("Version cmd >>>>>>", utils.stringify_table(cmd))
   print("<<< cmd.args.application_version >>>", cmd.args.application_version)
   print("<<< cmd.args.application_sub_version >>>", cmd.args.application_sub_version)
   --Monoprice older app version "13.7" with multichannel c.c report 
   local app_version = cmd.args.application_version .. ".".. cmd.args.application_sub_version
   device:set_field("app_version", app_version, {persist = true})
end

local monoprice_double_relay = {
  NAME = "monoprice double relay",
  capability_handlers = {
    
  },
  zwave_handlers = {
    [cc.MULTI_CHANNEL] = {
      [MultiChannel.CAPABILITY_REPORT] = multichannel_capability_report_handler
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = zwave_handlers_report
    },
    [cc.BASIC] = {
      [Basic.REPORT] = zwave_handlers_report
    },
    [cc.VERSION] = {
      [Version.REPORT] = version_report_handler
    },
  },
  lifecycle_handlers = {
    init = device_init
  },
  can_handle = can_handle_monoprice_double_relay,
}

return monoprice_double_relay
