local capabilities = require "st.capabilities"
--- @type st.utils
--local utils = require "st.utils"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.CentralScene
--local CentralScene = (require "st.zwave.CommandClass.CentralScene")({version=1})
--- @type st.zwave.CommandClass.SceneActivation
local SceneActivation = (require "st.zwave.CommandClass.SceneActivation")({ version=1 })
--- @type st.zwave.CommandClass.SwitchMultilevel
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({ version = 4 })
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })

--- Custom Capabilities
local forced_On_Level = capabilities["legendabsolute60149.forcedOnLevel"]

local FIBARO_DIMMER_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x0102, model = 0x1000}, -- Fibaro Dimmer2
  {mfr = 0x010F, prod = 0x0102, model = 0x1001}, -- Fibaro Dimmer2
  {mfr = 0x010F, prod = 0x0102, model = 0x2000}, -- Fibaro Dimmer2
  {mfr = 0x010F, prod = 0x0102, model = 0x3000}, -- Fibaro Dimmer2
}

local function can_handle_fibaro_dimmer2(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(FIBARO_DIMMER_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("fibaro-dimmer2")
      return true, subdriver
    end
  end
  return false
end


----- zwave_handlers_scene_activation_set
local function zwave_handlers_scene_activation_set(self, device, cmd)

  local event = capabilities.button.button.pushed
  local button_number = 2
  if cmd.args.scene_id == 10 or  cmd.args.scene_id == 20 then
    if cmd.args.scene_id == 10 then button_number = 1 end
    event = capabilities.button.button.pushed

  elseif cmd.args.scene_id == 11 or  cmd.args.scene_id == 21 then
    if cmd.args.scene_id == 11 then button_number = 1 end
    event = capabilities.button.button.held
  
  elseif cmd.args.scene_id == 16 or  cmd.args.scene_id == 26 then
    if cmd.args.scene_id == 16 then button_number = 1 end
    event = capabilities.button.button.pushed

  elseif cmd.args.scene_id == 15 or  cmd.args.scene_id == 25 then
    event = capabilities.button.button.pushed_3x

  elseif cmd.args.scene_id == 12 or  cmd.args.scene_id == 22 then
    if cmd.args.scene_id == 12 then button_number = 1 end
    event = capabilities.button.button.down_hold

  elseif cmd.args.scene_id == 13 or  cmd.args.scene_id == 23 then
    if cmd.args.scene_id == 13 and device.preferences.switchType == 2 then button_number = 1 end
    event = capabilities.button.button.held

  elseif cmd.args.scene_id == 14 or  cmd.args.scene_id == 24 then
    if cmd.args.scene_id == 14 then button_number = 1 end
    event = capabilities.button.button.double

    -- values 17 brightening and 18 are dimming 
  elseif cmd.args.scene_id == 17 or  cmd.args.scene_id == 18 then
    if cmd.args.scene_id == 17 then button_number = 1 end
    event = capabilities.button.button.pushed

  end

  local component = device.profile.components["button" .. button_number]

  if component ~= nil then
    device:emit_component_event(component, event({state_change = true}))
  end
end

--- switch_multilevel_report
local function switch_multilevel_report(driver, device, cmd)
  print("cmd.src_channel >>>>",cmd.src_channel)
  if cmd.src_channel < 2 then
   local event = nil
   local value = nil
   if cmd.args.target_value ~= nil then
     -- Target value is our best inidicator of eventual state.
     -- If we see this, it should be considered authoritative.
     value = cmd.args.target_value
   else
     value = cmd.args.value
   end
 
   if value ~= nil then -- level 0 is switch off, not level set
     device:emit_event(value > 0 and capabilities.switch.switch.on() or capabilities.switch.switch.off())
     if value == 99 then
       -- Directly map 99 to 100 to avoid rounding issues remapping 0-99 to 0-100
       value = 100
     end
     event = capabilities.switchLevel.level(value)
   end
 
   if event ~= nil then
     device:emit_event_for_endpoint(cmd.src_channel, event)
   end
  end
 end

 ---- init handler
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
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)

  -- get forcedOnLevel parameter 19 value
  device:send(Configuration:Get({ parameter_number = 19 }))
end

local function configuration_report(driver, device, cmd)
  local parameter_number = cmd.args.parameter_number
  local configuration_value = cmd.args.configuration_value

  if parameter_number == 19 then
    device:emit_event(forced_On_Level.forcedOnLevel(configuration_value))
  else
    device:emit_event(forced_On_Level.forcedOnLevel(0))
  end
end

--forced_On_Level_handler
local function forced_On_Level_handler(driver, device, command)
  print("<<< forced_On_Level_handler:", command.args.value)
  local forced_level = command.args.value
  if forced_level == 100 then forced_level = 99 end

  device:emit_event(forced_On_Level.forcedOnLevel(forced_level))
  
  -- Sent configuration parameter to device
  device:send(Configuration:Set({parameter_number = 19, size = 1, configuration_value = forced_level}))

end

local fibaro_dimmer2 = {
  NAME = "fibaro dimmer2",
  capability_handlers = {
    [forced_On_Level.ID] = {
      [forced_On_Level.commands.setForcedOnLevel.NAME] = forced_On_Level_handler,
    },
  },
  zwave_handlers = {
    [cc.SCENE_ACTIVATION] = {
      [SceneActivation.SET] = zwave_handlers_scene_activation_set
    },
    [cc.SWITCH_MULTILEVEL] = {
      [SwitchMultilevel.REPORT] = switch_multilevel_report,
    },
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report
    },
  },
  lifecycle_handlers = {
    init = device_init
  },
  can_handle = can_handle_fibaro_dimmer2,
}

return fibaro_dimmer2
