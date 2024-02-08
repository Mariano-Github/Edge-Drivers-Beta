-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })
--- @type st.zwave.CommandClass.SwitchColor
local SwitchColor = (require "st.zwave.CommandClass.SwitchColor")({ version = 3 })  --verison =1
--- @type st.zwave.CommandClass.SwitchMultilevel
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({ version = 4 }) --verison =1
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({ version = 2 })
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.CentralScene
local CentralScene = (require "st.zwave.CommandClass.CentralScene")({version=3})
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 }) --Manual verison =4

local utils = require "st.utils"

local ColorControlDefaults = require "st.zwave.defaults.colorControl"
local SwitchLevelDefaults = require "st.zwave.defaults.switchLevel"

local programmed_Sequence = capabilities["legendabsolute60149.programmedSequence"]

local CAP_CACHE_KEY = "st.capabilities." .. capabilities.colorControl.ID
local LAST_COLOR_SWITCH_CMD_FIELD = "lastColorSwitchCmd"
local FAKE_RGB_ENDPOINT = 10

local FIBARO_RGBW_CONTROLLER_FINGERPRINTS = {
  --{mfr = 0x010F, prod = 0x0902, model = 0x1000}, -- FIBARO_RGBW_CONTROLLER EU
  --{mfr = 0x010F, prod = 0x0902, model = 0x2000}, -- FIBARO_RGBW_CONTROLLER US
  --{mfr = 0x027A, prod = 0x0902, model = 0x2000}, -- ZOOZ RGBW_CONTROLLER US
  {mfr = 0x010F, prod = 0x0902}, -- FIBARO_RGBW_CONTROLLER 2
  {mfr = 0x027A, prod = 0x0902}, -- ZOOZ RGBW_CONTROLLER
}

local function is_fibaro_rgbw_controller(opts, driver, device, ...)
  for _, fingerprint in ipairs(FIBARO_RGBW_CONTROLLER_FINGERPRINTS) do
    --if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
    if device:id_match(fingerprint.mfr, fingerprint.prod) then
      local subdriver = require("fibaro-rgbw-controller-2")
      return true, subdriver
    end
  end
  return false
end


-- This handler is copied from defaults with scraped of sets for both WHITE channels
local function set_color(driver, device, command)
  local r, g, b = utils.hsl_to_rgb(command.args.color.hue, command.args.color.saturation, command.args.color.lightness)
  if r > 0 or g > 0 or b > 0 then
    device:set_field(CAP_CACHE_KEY, command)
  end
  local set = SwitchColor:Set({
    color_components = {
      { color_component_id=SwitchColor.color_component_id.RED, value=r },
      { color_component_id=SwitchColor.color_component_id.GREEN, value=g },
      { color_component_id=SwitchColor.color_component_id.BLUE, value=b },
    }
  })
  device:send(set)
  local query_color = function()
    -- Use a single RGB color key to trigger our callback to emit a color
    -- control capability update.
    if r ~= 0 and g ~= 0 and b ~= 0 then
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
    else
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
    end
  end
  device.thread:call_with_delay(constants.DEFAULT_GET_STATUS_DELAY, query_color)
end

local function switch_color_report(driver, device, command)
  local event
  if command.args.color_component_id == SwitchColor.color_component_id.WARM_WHITE then
    local value = command.args.value
    if value > 0 then
      event = capabilities.switch.switch.on()
    else
      event = capabilities.switch.switch.off()
    end
    device:emit_component_event(device.profile.components["white"], event)
  else
    if device:get_field(LAST_COLOR_SWITCH_CMD_FIELD) == 0 and command.args.value == 0 then
      event = capabilities.switch.switch.off()
    else
      event = capabilities.switch.switch.on()
    end
    device:emit_component_event(device.profile.components["rgb"], event)
    command.src_channel = FAKE_RGB_ENDPOINT
    ColorControlDefaults.zwave_handlers[cc.SWITCH_COLOR][SwitchColor.REPORT](self, device, command)
  end
end

local function switch_multilevel_report(driver, device, command)
  local endpoint = command.src_channel
  print("<<< EndPoint >>>", endpoint)
  print("<<< Component >>>", command.component)
  -- ignore multilevel reports from endpoints [1, 2, 3, 4] which mirror SwitchColor values
  -- and in addition cause wrong SwitchLevel events
  if not (endpoint >= 1 and endpoint <= 5) then
    if command.args.value == SwitchMultilevel.value.OFF_DISABLE then
      local event = capabilities.switch.switch.off()
      device:emit_component_event(device.profile.components["white"], event)
      device:emit_component_event(device.profile.components["rgb"], event)
    else
      --command.component = "main"
      --SwitchLevelDefaults.zwave_handlers[cc.SWITCH_MULTILEVEL][SwitchMultilevel.REPORT](self, device, command)
      --command.component = "rgb"
      --SwitchLevelDefaults.zwave_handlers[cc.SWITCH_MULTILEVEL][SwitchMultilevel.REPORT](self, device, command)
      --command.component = "white"
      --SwitchLevelDefaults.zwave_handlers[cc.SWITCH_MULTILEVEL][SwitchMultilevel.REPORT](self, device, command)

      local event = nil
      local value = command.args.value and command.args.value or command.args.target_value

      if value ~= nil and value > 0 then -- level 0 is switch off, not level set
        if value == 99 or value == 0xFF then
          -- Directly map 99 to 100 to avoid rounding issues remapping 0-99 to 0-100
          -- 0xFF is a (deprecated) reserved value that the spec requires be mapped to 100
          value = 100
        end
        event = capabilities.switchLevel.level(value)
      end

      if event ~= nil then
        device:emit_component_event(device.profile.components["white"], event)
        device:emit_component_event(device.profile.components["rgb"], event)
        device:emit_component_event(device.profile.components["main"], event)
        --device:emit_event_for_endpoint(cmd.src_channel, event)
      end
    end
    local query = function()
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
    end
    device.thread:call_with_delay(constants.DEFAULT_GET_STATUS_DELAY, query)
  end
end

local function set_switch(driver, device, command, value)
  if command.component == "white" or command.component == "main" then
    local set = SwitchColor:Set({
      color_components = {
        { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = value },
      }
    })
    device:send(set)
    local query_white = function()
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
    end
    --device.thread:call_with_delay(constants.DEFAULT_GET_STATUS_DELAY + constants.DEFAULT_DIMMING_DURATION, query_white)
    device.thread:call_with_delay(constants.DEFAULT_GET_STATUS_DELAY, query_white)
  end
  if command.component == "rgb" or command.component == "main" then
    device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, value)
    if value == 255 then
      local setColorCommand = device:get_field(CAP_CACHE_KEY)
      if setColorCommand ~= nil then
        set_color(driver, device, setColorCommand)
      else
        local mockCommand = {args = {color = {hue = 0, saturation = 50}}}
        set_color(driver, device, mockCommand)
      end
    else
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.RED, value=0 },
          { color_component_id=SwitchColor.color_component_id.GREEN, value=0 },
          { color_component_id=SwitchColor.color_component_id.BLUE, value=0 }
        }
      })
      device:send(set)
      local query_color = function()
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
      end
      device.thread:call_with_delay(constants.DEFAULT_GET_STATUS_DELAY, query_color)
    end
  end
  --if command.component == "main" then
    local event = capabilities.switch.switch.off()
    print("value >>>>>",value)
    if value == 255 then
      event = capabilities.switch.switch.on()
      device:emit_component_event(device.profile.components["main"], event)
    else
      if device:get_latest_state("rgb", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and  device:get_latest_state("white", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        device:emit_component_event(device.profile.components["main"], event)
      end
    end
end

local function set_switch_on(driver, device, command)
  set_switch(driver, device, command, 255)
end

local function set_switch_off(driver, device, command)
  set_switch(driver, device, command, 0)
end

local function device_added(self, device)
  device:send(Association:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}}))
  device:refresh()
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

local function endpoint_to_component(device, ep)
  if ep == FAKE_RGB_ENDPOINT then
    return "rgb"
  else
    return "main"
  end
end

local function device_init(self, device)
  device:set_endpoint_to_component_fn(endpoint_to_component)

  if device.preferences.changeProfile2 == "Single" then
    device:try_update_metadata({profile = "fibaro-rgbw-controller-2"})
  else
    device:try_update_metadata({profile = "fibaro-rgbw-controller-2-multi"})
  end

  -- get forcedOnLevel parameter 157 value programmedSequence
  device:send(Configuration:Get({ parameter_number = 157 }))
  --if device.get_field("programmed_Sequence_set") == nil then device:set_field("programmed_Sequence_set", "Inactive", {persist = true}) end
  --device:emit_event(programmed_Sequence.programmedSequence(device.get_field("programmed_Sequence_set")))
end

--programmed_Sequence_handler
local function programmed_Sequence_handler(self, device, command)
  print("programmed_Sequence Value", command.args.value)
  local programmed_Sequence_set = command.args.value
  --device:set_field("programmed_Sequence_set", programmed_Sequence_set, {persist = true})
  device:emit_event(programmed_Sequence.programmedSequence(programmed_Sequence_set))
  
  local parameter_value = 0
  if programmed_Sequence_set == "Fireplace" then
    parameter_value = 6
  elseif programmed_Sequence_set == "Storm" then
    parameter_value = 7
  elseif programmed_Sequence_set == "Rainbow" then
    parameter_value = 8
  elseif programmed_Sequence_set == "Aurora" then
    parameter_value = 9
  elseif programmed_Sequence_set == "Police" then
    parameter_value = 10
  end

  device:send(Configuration:Set({parameter_number = 157, size = 1, configuration_value = parameter_value}))

end

-- emit programmed_Sequence read from device
local function configuration_report(driver, device, cmd)
  local parameter_number = cmd.args.parameter_number
  local configuration_value = cmd.args.configuration_value

  if parameter_number == 157 then
    local programmed_Sequence_set = "Inactive"
    if configuration_value == 6 then
      programmed_Sequence_set = "Fireplace"
    elseif configuration_value == 7 then
      programmed_Sequence_set = "Storm"
    elseif configuration_value == 8 then
      programmed_Sequence_set = "Rainbow"
    elseif configuration_value == 9 then
      programmed_Sequence_set = "Aurora"
    elseif configuration_value == 10 then
      programmed_Sequence_set = "Police"
    end
    print("programmed_Sequence_set", programmed_Sequence_set)
    device:emit_event(programmed_Sequence.programmedSequence(programmed_Sequence_set))
  end
end

local fibaro_rgbw_controller2 = {
  NAME = "Fibaro RGBW Controller 2",
  zwave_handlers = {
    [cc.SWITCH_COLOR] = {
      [SwitchColor.REPORT] = switch_color_report
    },
    [cc.SWITCH_MULTILEVEL] = {
      [SwitchMultilevel.REPORT] = switch_multilevel_report
    },
    [cc.CENTRAL_SCENE] = {
      [CentralScene.NOTIFICATION] = central_scene_notification_handler
    },
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report
    },
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = set_switch_on,
      [capabilities.switch.commands.off.NAME] = set_switch_off
    },
    [capabilities.colorControl.ID] = {
      [capabilities.colorControl.commands.setColor.NAME] = set_color
    },
    [programmed_Sequence.ID] = {
      [programmed_Sequence.commands.setProgrammedSequence.NAME] = programmed_Sequence_handler,
    },
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init
  },
  can_handle = is_fibaro_rgbw_controller,
}

return fibaro_rgbw_controller2
