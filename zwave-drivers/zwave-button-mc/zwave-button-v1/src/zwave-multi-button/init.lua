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
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.CentralScene
local CentralScene = (require "st.zwave.CommandClass.CentralScene")({ version=1 })
--- @type st.zwave.CommandClass.SceneActivation
local SceneActivation = (require "st.zwave.CommandClass.SceneActivation")({ version=1 })
--- @type st.zwave.CommandClass.Association
--local Association = (require "st.zwave.CommandClass.Association")({ version=2 })
--local SceneControllerConf = (require "st.zwave.CommandClass.SceneControllerConf")({ version=1 })
--local utils = require "st.utils"

local ZWAVE_MULTI_BUTTON_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x1001, model = 0x1000}, -- Fibaro KeyFob EU
  {mfr = 0x010F, prod = 0x1001, model = 0x2000}, -- Fibaro KeyFob US
  {mfr = 0x010F, prod = 0x1001, model = 0x3000}, -- Fibaro KeyFob AU
  {mfr = 0x0371, prod = 0x0002, model = 0x0003}, -- Aeotec NanoMote Quad EU
  {mfr = 0x0371, prod = 0x0102, model = 0x0003}, -- Aeotec NanoMote Quad US
  {mfr = 0x0086, prod = 0x0001, model = 0x0058}, -- Aeotec KeyFob EU
  {mfr = 0x0086, prod = 0x0101, model = 0x0058}, -- Aeotec KeyFob US
  {mfr = 0x0086, prod = 0x0002, model = 0x0082}, -- Aeotec Wallmote Quad EU
  {mfr = 0x0086, prod = 0x0102, model = 0x0082}, -- Aeotec Wallmote Quad US
  {mfr = 0x0086, prod = 0x0002, model = 0x0081}, -- Aeotec Wallmote EU
  {mfr = 0x0086, prod = 0x0102, model = 0x0081}, -- Aeotec Wallmote US
  {mfr = 0x0060, prod = 0x000A, model = 0x0003}, -- Everspring Remote Control
  {mfr = 0x0086, prod = 0x0001, model = 0x0003}, -- Aeotec Mimimote
  {mfr = 0x0371, prod = 0x0102, model = 0x0016}, -- Aeotec illumino Wallmote 7
  {mfr = 0x5254, prod = 0x0000, model = 0x8510}, -- Remotec zrc-90
  {mfr = 0x5254, prod = 0x0001, model = 0x8510}, -- Remotec zrc-90
  {mfr = 0x5254, prod = 0x0002, model = 0x8510}, -- Remotec zrc-90 AU
  {mfr = 0x0208, prod = 0x0201, model = 0x000B},  -- Hank Four-Key Scene Controller
  {mfr = 0x0438, prod = 0x0300, model = 0xA305},  -- NAMRON Z-WAVE 4 KANALER BRYTER
  {mfr = 0x0438, prod = 0x0300, model = 0xA306},  -- NAMRON Z-WAVE 2 KANALER BRYTER
  {mfr = 0x0438, prod = 0x0300, model = 0xA30F},  -- NAMRON Z-WAVE 1 KANALER BRYTER
  {mfr = 0x0330, prod = 0x0300, model = 0xA30F},  -- NAMRON Z-WAVE 1 KANALER BRYTER
  {mfr = 0x0330, prod = 0x0300, model = 0xA310},  -- NAMRON Z-WAVE 2 KANALER BRYTER
  {mfr = 0x014F, prod = 0x5343, model = 0x3132},  -- GO_CONTROL_WA00Z_1 2 button
  {mfr = 0x011A, prod = 0x0801, model = 0x0B03},  -- ZWNSC7 Enerwave Scene Master
  {mfr = 0x0178, prod = 0x5343, model = 0x4735},  -- Nexia Nx-1000 15 buttons
  {mfr = 0x026E, prod = 0x5643, model = 0x5A31},  -- Somfy 2 Buttons
  {mfr = 0x026E, prod = 0x4252, model = 0x5A31},  -- Somfy 3 Buttons
  {mfr = 0x0267, prod = 0x0002, model = 0x0000},  -- SIMON S100 SWITCH IO 1 Button
  {mfr = 0x0267, prod = 0x0105, model = 0x0000},  -- SIMON S100 SWITCH IO 1 Button
  {mfr = 0x0109, prod = 0x1002, model = 0x0202},  -- VisionZT1101-5 / 4-buttons
  {mfr = 0x0305, prod = 0x0300, model = 0x0075},  -- FUTUREHOME Z-WAVE 2 KANAL
  {mfr = 0x014F, prod = 0x5754, model = 0x3530},  -- GO_CONTROL_WA00Z_1S 2 button
  {mfr = 0x0109, prod = 0x1004, model = 0x0402},  -- VisionZT1141-5 / 4-buttons
  {mfr = 0x0109, prod = 0x1004, model = 0x0403},  -- VisionZT1141-5 / 4-buttons
}

local function can_handle_zwave_multi_button(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end -- is CHILD DEVICE
  for _, fingerprint in ipairs(ZWAVE_MULTI_BUTTON_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return true
    end
  end
  return false
end

local map_key_attribute_to_capability = {
  [CentralScene.key_attributes.KEY_PRESSED_1_TIME] = capabilities.button.button.pushed,
  [CentralScene.key_attributes.KEY_RELEASED] = capabilities.button.button.held,
  [CentralScene.key_attributes.KEY_HELD_DOWN] = capabilities.button.button.down_hold,
  [CentralScene.key_attributes.KEY_PRESSED_2_TIMES] = capabilities.button.button.double,
  [CentralScene.key_attributes.KEY_PRESSED_3_TIMES] = capabilities.button.button.pushed_3x,
  [CentralScene.key_attributes.KEY_PRESSED_4_TIMES] = capabilities.button.button.pushed_4x,
  [CentralScene.key_attributes.KEY_PRESSED_5_TIMES] = capabilities.button.button.pushed_5x
}

local function central_scene_notification_handler(self, device, cmd)
  --print("cmd.args.key_attributes >>>>>", cmd.args.key_attributes)
  --print("cmd.args.scene_number >>>>>>",cmd.args.scene_number)
  --print("cmd.args.sequence_number >>>>>>",cmd.args.sequence_number)
  local event = map_key_attribute_to_capability[cmd.args.key_attributes]({state_change = true})
  if event ~= nil then
    local supportedEvents = device:get_latest_state(
      device:endpoint_to_component(cmd.args.scene_number),
      capabilities.button.ID,
      capabilities.button.supportedButtonValues.NAME,
      {capabilities.button.button.pushed.NAME, capabilities.button.button.held.NAME} -- default value
    )
    for _, event_name in pairs(supportedEvents) do
      if event.value.value == event_name then
        device:emit_event_for_endpoint(cmd.args.scene_number, event)
        device:emit_event(event)
      end
    end
  end
  --device:emit_event_for_endpoint(cmd.args.scene_number, event)
  --device:emit_event(event)
end

local function scene_activation_handler(self, device, cmd)
  for _, fingerprint in ipairs(ZWAVE_MULTI_BUTTON_FINGERPRINTS) do
    if device:id_match(0x5254, 0x0001, 0x8510) or device:id_match(0x5254, 0x0000, 0x8510) or device:id_match(0x5254, 0x0002, 0x8510) then
      print("Remotec >>>>>")
      return
    end
  end
  local scene_id = cmd.args.scene_id
  if device.zwave_manufacturer_id == 0x011A and device.zwave_product_type == 0x0801 and device.zwave_product_id == 0x0B03 then
    local event =  capabilities.button.button.pushed
    local component = device.profile.components["button" .. scene_id]

    if component ~= nil then
      device:emit_component_event(component, event({state_change = true}))
    end
  elseif device.zwave_manufacturer_id == 0x0109 and device.zwave_product_type == 0x1002 and device.zwave_product_id == 0x0202 then
    local event =  capabilities.button.button.pushed
    local component
    if scene_id == 1 then 
      component = device.profile.components["button" .. "1"]
    elseif scene_id == 3 then 
      component = device.profile.components["button" .. "2"]
    elseif scene_id == 5 then 
      component = device.profile.components["button" .. "3"]
    elseif scene_id == 7 then 
      component = device.profile.components["button" .. "4"]
    elseif scene_id == 2 then 
      component = device.profile.components["button" .. "1"]
      event =  capabilities.button.button.down_hold
    elseif scene_id == 4 then 
      component = device.profile.components["button" .. "2"]
      event =  capabilities.button.button.down_hold
    elseif scene_id == 6 then 
      component = device.profile.components["button" .. "3"]
      event =  capabilities.button.button.down_hold
    elseif scene_id == 8 then 
      component = device.profile.components["button" .. "4"]
      event =  capabilities.button.button.down_hold
    end

    if component ~= nil then
      device:emit_component_event(component, event({state_change = true}))
    end
  else
    local event = scene_id % 2 == 0 and capabilities.button.button.held or capabilities.button.button.pushed
    device:emit_event_for_endpoint((scene_id + 1) // 2, event({state_change = true}))
    device:emit_event(event({state_change = true}))
  end
end

local function component_to_endpoint(device, component_id)
  local ep_num = component_id:match("button(%d)")
  return { ep_num and tonumber(ep_num) } -- or {}
end

local function endpoint_to_component(device, ep)
  local button_comp = string.format("button%d", ep)
  if device.profile.components[button_comp] ~= nil then
    return button_comp
  else
    return "main"
  end
end

local function device_init(driver, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)
  
end

local zwave_multi_button = {
  NAME = "Z-Wave multi button",
  zwave_handlers = {
    [cc.CENTRAL_SCENE] = {
      [CentralScene.NOTIFICATION] = central_scene_notification_handler
    },
    [cc.SCENE_ACTIVATION] = {
      [SceneActivation.SET] = scene_activation_handler
    }
  },
  lifecycle_handlers = {
    init = device_init
  },
  can_handle = can_handle_zwave_multi_button,
  sub_drivers = { 
    require("zwave-multi-button/aeotec-keyfob"),
    require("zwave-multi-button/fibaro-keyfob"),
    require("zwave-multi-button/aeotec-minimote")
  }
}

return zwave_multi_button
