--- M. Colmenarejo 2024
--- Smartthings library load ---
local capabilities = require "st.capabilities"
local log = require "log"
--local utils = require "st.utils"

-- Custom Capability Randon On Off
local text_Field_One = capabilities["legendabsolute60149.textFieldOne"]
local text_Field_Two = capabilities["legendabsolute60149.textFieldTwo"]
local text_Field_Three = capabilities["legendabsolute60149.textFieldThree"]
local text_Field_Four = capabilities["legendabsolute60149.textFieldFour"]
local text_Field_Five = capabilities["legendabsolute60149.textFieldFive"]



-- added and refresh device
local function device_added(driver, device,command)
  --print("Table command >>>>>>",utils.stringify_table(command))
  --print("<<<< command.commad",command.command)
  if command.command == "refresh" then
    log.info("[" .. device.id .. "] Refresh Virtual Device")
  else
    log.info("[" .. device.id .. "] Adding new Virtual Device")
  end

  if device:get_latest_state("main", text_Field_One.ID, text_Field_One.textFieldOne.NAME) == nil then
    device:emit_event(text_Field_One.textFieldOne(" "))
  end
  if device:get_latest_state("main", text_Field_Two.ID, text_Field_Two.textFieldTwo.NAME) == nil then
    device:emit_event(text_Field_Two.textFieldTwo(" "))
  end
  if device:get_latest_state("main", text_Field_Three.ID, text_Field_Three.textFieldThree.NAME) == nil then
    device:emit_event(text_Field_Three.textFieldThree(" "))
  end
  if device:get_latest_state("main", text_Field_Four.ID, text_Field_Four.textFieldFour.NAME) == nil then
    device:emit_event(text_Field_Four.textFieldFour(" "))
  end
  if device:get_latest_state("main", text_Field_Five.ID, text_Field_Five.textFieldFive.NAME) == nil then
    device:emit_event(text_Field_Five.textFieldFive(" "))
  end
end

local function device_init(driver, device) 
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
  if device.model ~= "Virtual Text Field-5" then
    device:try_update_metadata({ model = "Virtual Text Field-5" })
    device.thread:call_with_delay(5, function() 
      print("<<<<< model= ", device.model)
    end)
  end

  local event = device:get_latest_state("main", text_Field_One.ID, text_Field_One.textFieldOne.NAME)
  if event == nil then 
    event = ""
    device:emit_event(text_Field_One.textFieldOne(event))
  end
  
  event = device:get_latest_state("main", text_Field_Two.ID, text_Field_Two.textFieldTwo.NAME)
  if event == nil then 
    event = ""
    device:emit_event(text_Field_Two.textFieldTwo(event))
  end

  event = device:get_latest_state("main", text_Field_Three.ID, text_Field_Three.textFieldThree.NAME)
  if event == nil then 
    event = ""
    device:emit_event(text_Field_Three.textFieldThree(event))
  end

  event = device:get_latest_state("main", text_Field_Four.ID, text_Field_Four.textFieldFour.NAME)
  if event == nil then 
    event = ""
    device:emit_event(text_Field_Four.textFieldFour(event))
  end

  event = device:get_latest_state("main", text_Field_Five.ID, text_Field_Five.textFieldFive.NAME)
  if event == nil then 
    event = ""
    device:emit_event(text_Field_Five.textFieldFive(event))
  end

end

--command_handlers.setTextField_One_handler
local function setText_Field_One_handler(driver, device, command)
  device:emit_event(text_Field_One.textFieldOne(command.args.value))
end

--command_handlers.setTextField_Two_handler
local function setText_Field_Two_handler(driver, device, command)
  device:emit_event(text_Field_Two.textFieldTwo(command.args.value))
end

--command_handlers.setTextField_Three_handler
local function setText_Field_Three_handler(driver, device, command)
  device:emit_event(text_Field_Three.textFieldThree(command.args.value))
end

--command_handlers.setTextField_Four_handler
local function setText_Field_Four_handler(driver, device, command)
  device:emit_event(text_Field_Four.textFieldFour(command.args.value))
end

--command_handlers.setTextField_Five_handler
local function setText_Field_Five_handler(driver, device, command)
  device:emit_event(text_Field_Five.textFieldFive(command.args.value))
end

local virtual_text_fields = {
	NAME = "virtual text fields",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_added,
    },
    [text_Field_One.ID] = {
      [text_Field_One.commands.setTextFieldOne.NAME] = setText_Field_One_handler
    },
    [text_Field_Two.ID] = {
      [text_Field_Two.commands.setTextFieldTwo.NAME] = setText_Field_Two_handler
    },
    [text_Field_Three.ID] = {
      [text_Field_Three.commands.setTextFieldThree.NAME] = setText_Field_Three_handler
    },
    [text_Field_Four.ID] = {
      [text_Field_Four.commands.setTextFieldFour.NAME] = setText_Field_Four_handler
    },
    [text_Field_Five.ID] = {
      [text_Field_Five.commands.setTextFieldFive.NAME] = setText_Field_Five_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
  },

  can_handle =  require("virtual-text-fields.can_handle")
}
return virtual_text_fields