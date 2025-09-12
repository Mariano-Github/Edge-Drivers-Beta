local capabilities = require "st.capabilities"
--- @type st.utils
--local utils = require "st.utils"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.CentralScene
local CentralScene = (require "st.zwave.CommandClass.CentralScene")({version=1})

local INOVELLI_DIMMER_FINGERPRINTS = {
  {mfr = 0x0312, prod = 0x1F00, model = 0x1F00}, -- Inovelli dimmer
  {mfr = 0x0312, prod = 0x1F02, model = 0x1F02}, -- Inovelli dimmer toggle
  {mfr = 0x015D, prod = 0xB111, model = 0x251C}, -- Inovelli dimmer
  {mfr = 0x051D, prod = 0xB111, model = 0x251C}, -- Inovelli dimmer
  {mfr = 0x015D, prod = 0x1F00, model = 0x1F00}, -- Inovelli dimmer
  {mfr = 0x0312, prod = 0x1E00, model = 0x1E00}, -- Inovelli switch nzw30
  {mfr = 0x0312, prod = 0x1E02, model = 0x1E02}, -- Inovelli switch nzw30 toggle
  {mfr = 0x015D, prod = 0xB111, model = 0x1E1C}, -- Inovelli switch nzw30
  {mfr = 0x015D, prod = 0x1E00, model = 0x1E00}, -- Inovelli switch nzw30
}

local function can_handle_inovelli_dimmer(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(INOVELLI_DIMMER_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("inovelli-nzw31")
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
    [CentralScene.key_attributes.KEY_PRESSED_3_TIMES] = capabilities.button.button.pushed_3x,
    [CentralScene.key_attributes.KEY_PRESSED_4_TIMES] = capabilities.button.button.pushed_4x,
    [CentralScene.key_attributes.KEY_PRESSED_5_TIMES] = capabilities.button.button.pushed_5x
  }

  local event = map_key_attribute_to_capability[cmd.args.key_attributes]
  local button_number = "downButton"
  if cmd.args.scene_number == 2 then
    button_number = "upButton"
  end

  local component = device.profile.components[button_number]

  if component ~= nil then
    device:emit_component_event(component, event({state_change = true}))
  end
end

local inovelli_dimmer = {
  NAME = "inovelli dimmer",
  zwave_handlers = {
    [cc.CENTRAL_SCENE] = {
      [CentralScene.NOTIFICATION] = central_scene_notification_handler
    }
  },
  lifecycle_handlers = {

  },
  can_handle = can_handle_inovelli_dimmer,
}

return inovelli_dimmer
