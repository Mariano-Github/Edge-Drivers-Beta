local capabilities = require "st.capabilities"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.CommandClass
local cc  = require "st.zwave.CommandClass"
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({version=1,strict=true})
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=2,strict=true})
--- @type st.zwave.CommandClass.SwitchMultilevel
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({version=4,strict=true})
local Version = (require "st.zwave.CommandClass.Version")({ version = 2 })
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })

--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
--local preferencesMap = require "preferences"
local configurationsMap = require "configurations"
local child_devices = require "child-devices"

--local on_off_defaults = require "st.zwave.defaults.switch"
--local capability_handlers = on_off_defaults.capability_handlers

--- Map component to end_points(channels)
---
--- @param device st.zwave.Device
--- @param component_id string ID
--- @return table dst_channels destination channels e.g. {2} for Z-Wave channel 2 or {} for unencapsulated
local function component_to_endpoint(device, component_id)
  local ep_supplement = 0
  --print("<<<< device.zwave_manufacturer_id >>>>>> ",device.zwave_manufacturer_id)

  if device.zwave_manufacturer_id == 0x0293 or
    (device.zwave_manufacturer_id == 0x0086 and device.preferences.switch1Child ~= nil) or
    device.zwave_manufacturer_id == 0x0109 or
    device.zwave_manufacturer_id == 0x015F or
    (device.zwave_manufacturer_id == 0x0068 and device.zwave_product_type == 0x0003) or
    (device.zwave_manufacturer_id == 0x0099 and device.zwave_product_type == 0x0003) or
    (device.zwave_manufacturer_id == 0x027A and device.zwave_product_type == 0xA000 and device.zwave_product_id == 0xA004) or
    device.zwave_manufacturer_id == 0x0298 or
    device.zwave_manufacturer_id == 0x045A or
    device.zwave_manufacturer_id == 0x0460 or
    (device.zwave_manufacturer_id == 0x011A and device.zwave_product_type == 0x0111) then
      ep_supplement = 1 
  end
  local ep_num = tonumber(component_id:match("switch(%d)"))
  if ep_num == nil then
    --device:set_field("app_version") == "13.7" = monoprice double relay 0x0109 old app version
    if device:get_field("app_version") == "13.7" or 
    device.zwave_manufacturer_id == 0x015F or
    device.zwave_manufacturer_id == 0x0298 or
    device.zwave_manufacturer_id == 0x0460 or
    (device.zwave_manufacturer_id == 0x0086 and device.preferences.switch1Child ~= nil) then  --and device.zwave_product_type == 0x0203 then 
      return {1}
    else
     return {}
    end
  else
    return {ep_num + ep_supplement}
  end
end

--- Map end_point(channel) to Z-Wave endpoint 9 channel)
---
--- @param device st.zwave.Device
--- @param ep number the endpoint(Z-Wave channel) ID to find the component for
--- @return string the component ID the endpoint matches to
local function endpoint_to_component(device, ep)
  local ep_supplement = 0
  --print("<<<< device.zwave_manufacturer_id >>>>>> ",device.zwave_manufacturer_id)

  if device.zwave_manufacturer_id == 0x0293 or
  (device.zwave_manufacturer_id == 0x0086 and device.preferences.switch1Child ~= nil) or
    device.zwave_manufacturer_id == 0x0109 or
    device.zwave_manufacturer_id == 0x015F or
    (device.zwave_manufacturer_id == 0x0068 and device.zwave_product_type == 0x0003 ) or
    (device.zwave_manufacturer_id == 0x0099 and device.zwave_product_type == 0x0003) or
    (device.zwave_manufacturer_id == 0x027A and device.zwave_product_type == 0xA000 and device.zwave_product_id == 0xA004) or
    device.zwave_manufacturer_id == 0x0298 or
    device.zwave_manufacturer_id == 0x045A or
    device.zwave_manufacturer_id == 0x0460 or
    (device.zwave_manufacturer_id == 0x011A and device.zwave_product_type == 0x0111 ) then  
      ep_supplement = 1 
  end
  local switch_comp = string.format("switch%d", (ep - ep_supplement))
  if device.profile.components[switch_comp] ~= nil then
    return switch_comp
  else
    return "main"
  end
end

--- Initialize device
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
local device_init = function(self, device)

  --print("<<< device.network_type",device.network_type)
  --print("<< device.id:", device.id)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<<<< Main device_init >>>>>")
    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)
    
  else   ------------- profile init for child device config
    print("<<<<< Child device_config_init >>>>>")
    local parent_device = device:get_parent_device()
    if device.parent_assigned_child_key == "main" then -- is child device config
      if device.preferences.changeConfigProfile == "Info" then
        device:try_update_metadata({profile = "zwave-device-info"})
        parent_device:send(Version:Get({}))
      elseif device.preferences.changeConfigProfile == "Config" then
        device:try_update_metadata({profile = "zwave-config"})
      elseif device.preferences.changeConfigProfile == "Param" then
        device:try_update_metadata({profile = "zwave-parameter-info"})
      elseif device.preferences.changeConfigProfile == "GroupScan" then
        device:try_update_metadata({profile = "zwave-device-groups-scan"})
      elseif device.preferences.changeConfigProfile == "Group" then
        device:try_update_metadata({profile = "zwave-device-groups"})
      else
        device:try_update_metadata({profile = "zwave-device-info"})
        parent_device:send(Version:Get({}))
      end
      device:refresh()
    end
  end
end

--- Configure device
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function do_configure(driver, device)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local configuration = configurationsMap.get_device_configuration(device)
    if configuration ~= nil then
      for _, value in ipairs(configuration) do
        device:send(Configuration:Set({parameter_number = value.parameter_number, size = value.size, configuration_value = value.configuration_value}))
      end
    end
  end
end

local function device_added(self, device)
  print("<<<<< device_added in main driver >>>>>>>")
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)

    if (device.zwave_manufacturer_id == 0x011A and device.zwave_product_type == 0x0111 and device.zwave_product_id == 0x0606) then
      device:send(Association:Set({grouping_identifier = 2, node_ids = {self.environment_info.hub_zwave_id}}))
    elseif (device.zwave_manufacturer_id == 0x0118 and device.zwave_product_type == 0x0311 and device.zwave_product_id == 0x0201) or -- TKB Home TZ55S Plus Dimmer
      (device.zwave_manufacturer_id == 0xFFFF and device.zwave_product_type == 0x0003 and device.zwave_product_id == 0x0004) then -- TKB Home TZ55S Plus Dimmer
        device:send(Association:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}}))
    elseif device.zwave_manufacturer_id == 0x010F and 
      (device.zwave_product_type == 0x0200 or 
      device.zwave_product_type == 0x0202 or
      device.zwave_product_type == 0x0402)  then -- Fgs-221 & fgs-212
        device:send(Association:Set({grouping_identifier = 3, node_ids = {self.environment_info.hub_zwave_id}}))
    end
    device:refresh()
  else
    child_devices.device_added(self, device)
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
  if device:is_cc_supported(cc.SWITCH_BINARY) then
    --log.trace_with({ hub_logs = true }, "SWITCH_BINARY supported.")
    set = SwitchBinary:Set({
      target_value = value,
      duration = 0
    })
    get = SwitchBinary:Get({})
  elseif device:is_cc_supported(cc.SWITCH_MULTILEVEL) then
    --log.trace_with({ hub_logs = true }, "SWITCH_MULTILEVEL supported.")
    set = SwitchMultilevel:Set({
      value = value,
      duration = constants.DEFAULT_DIMMING_DURATION
    })
    delay = constants.MIN_DIMMING_GET_STATUS_DELAY
    get = SwitchMultilevel:Get({})
  else
    -- log.trace_with({ hub_logs = true }, "SWITCH_BINARY and SWITCH_MULTILEVEL NOT supported. Use Basic.Set()")
    set = Basic:Set({
      value = value
    })
    get = Basic:Get({})
  end
  device:send_to_component(set, command.component)
  local query_device = function()
    device:send_to_component(get, command.component)
  end
  device.thread:call_with_delay(delay, query_device)
end

--- switch_on_handler
local function switch_on_handler(driver, device, command)
  print("<<<<< switch_on_handler in main driver >>>>>>>")

  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:emit_event(capabilities.switch.switch.on())
    command.component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    switch_set_helper(driver, parent_device, 255, command)
  else
    switch_set_helper(driver, device, SwitchBinary.value.ON_ENABLE, command)
    local child_device = device:get_child_by_parent_assigned_key(command.component)
    if command.component ~= "main" and child_device ~= nil then

      child_device:emit_event(capabilities.switch.switch.on())
    end
  end
end

--- switch_off_handler
local function switch_off_handler(driver,device,command)
  print("<<<<< switch_off_handler in main driver >>>>>>>")

  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:emit_event(capabilities.switch.switch.off())
    command.component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    switch_set_helper(driver, parent_device, 0, command)
  else
    switch_set_helper(driver, device, SwitchBinary.value.OFF_DISABLE, command)
    local child_device = device:get_child_by_parent_assigned_key(command.component)
    if command.component ~= "main" and child_device ~= nil then
      child_device:emit_event(capabilities.switch.switch.off())
    end
  end
end

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
    child_device:emit_event(event)
  end
end

-- This functionality was present in "Z-Wave Dimmer Switch Generic" and, while non-standard,
-- appears to be important for some devices.
local function switch_multilevel_stop_level_change_handler(driver, device, cmd)
  device:emit_event_for_endpoint(cmd.src_channel, capabilities.switch.switch.on())
  device:send(SwitchMultilevel:Get({}))
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
local function lazy_load_if_possible(sub_driver_name)
  -- gets the current lua libs api version
  local version = require "version"

  --print("<<<<< Library Version:", version.api)
  -- version 9 will include the lazy loading functions
  if version.api >= 9 then
    return ZwaveDriver.lazy_load_sub_driver(require(sub_driver_name))
  else
    return require(sub_driver_name)
  end
end

-------------------------------------------------------------------------------------------
-- Register message handlers and run driver
-------------------------------------------------------------------------------------------
local driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.switchLevel,
    capabilities.battery,
    capabilities.energyMeter,
    capabilities.powerMeter,
    capabilities.colorControl,
    capabilities.button,
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.refresh
  },
  sub_drivers = {
    lazy_load_if_possible("eaton-accessory-dimmer"),
    lazy_load_if_possible("inovelli-LED"),
    lazy_load_if_possible("inovelli-nzw31"),
    lazy_load_if_possible("dawon-smart-plug"),
    lazy_load_if_possible("inovelli-2-channel-smart-plug"),
    lazy_load_if_possible("zwave-dual-switch"),
    lazy_load_if_possible("eaton-anyplace-switch"),
    lazy_load_if_possible("fibaro-wall-plug-us"),
    lazy_load_if_possible("dawon-wall-smart-switch"),
    lazy_load_if_possible("zooz-switch"),
    lazy_load_if_possible("zooz-power-strip"),
    lazy_load_if_possible("aeon-smart-strip"),
    lazy_load_if_possible("qubino-switches"),
    lazy_load_if_possible("fibaro-double-switch"),
    lazy_load_if_possible("fibaro-single-switch"),
    lazy_load_if_possible("fibaro-double-relay"),
    lazy_load_if_possible("fibaro-dimmer2"),
    lazy_load_if_possible("fibaro-dimmer1"),
    lazy_load_if_possible("fibaro-realy"),
    lazy_load_if_possible("fibaro-plug-old"),
    lazy_load_if_possible("eaton-5-scene-keypad"),
    lazy_load_if_possible("ecolink-switch"),
    lazy_load_if_possible("zooz-zen-30-dimmer-relay"),
    lazy_load_if_possible("monoprice-double-relay"),
    --lazy_load_if_possible("device-config"),
    require("device-config"),
    lazy_load_if_possible("basic-command")
  },
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    added = device_added,
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_on_handler,
      [capabilities.switch.commands.off.NAME] = switch_off_handler
    },
  },
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.REPORT] = zwave_handlers_report
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = zwave_handlers_report
    },
    [cc.SWITCH_MULTILEVEL] = {
      [SwitchMultilevel.STOP_LEVEL_CHANGE] = switch_multilevel_stop_level_change_handler
    }
  },
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local switch = ZwaveDriver("zwave_switch", driver_template)
switch:run()
