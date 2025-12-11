-- M. Colmenarejo 2024
--local log = require "log"
local capabilities = require "st.capabilities"
local log = require "log"

local number_Field_One = capabilities["legendabsolute60149.numberFieldOne"]
local number_Field_Two = capabilities["legendabsolute60149.numberFieldTwo"]
local number_Field_Three = capabilities["legendabsolute60149.numberFieldThree"]
local number_Field_Four = capabilities["legendabsolute60149.numberFieldFour"]
local number_Field_Five = capabilities["legendabsolute60149.numberFieldFive"]
local calculation_Result = capabilities["legendabsolute60149.calculationResult"]
local text_Formula = capabilities["legendabsolute60149.textFormula"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]

--local number_fields = {}

---- Calculator functions
local function calculator(driver, device, command, set_text_formula)

  local result = 0
  local error =  1
  local formula = set_text_formula
  local formula_leng = string.len(formula)
  if device.preferences.logDebugPrint == true then
    print("<<< set_text_formula:", set_text_formula)
    print("<<< formula_leng:", formula_leng)
  end
  local character = {}
  for num= 1, formula_leng, 1 do
    character[num] = string.char(string.byte(formula, num))
    if device.preferences.logDebugPrint == true then
      print("character_num-", num, character[num])
    end
  end


  local num={}
  num[1] = device:get_latest_state("main", number_Field_One.ID, number_Field_One.numberFieldOne.NAME)
  num[2] = device:get_latest_state("main", number_Field_Two.ID, number_Field_Two.numberFieldTwo.NAME)
  num[3] = device:get_latest_state("main", number_Field_Three.ID, number_Field_Three.numberFieldThree.NAME)
  num[4] = device:get_latest_state("main", number_Field_Four.ID, number_Field_Four.numberFieldFour.NAME)
  num[5] = device:get_latest_state("main", number_Field_Five.ID, number_Field_Five.numberFieldFive.NAME)

  if formula_leng == 1 then
    error = 1

  elseif (character[1] == "A" or character[1] == "a") and formula_leng == 2 then -- Average value of fields selected

    if character[2] == "1" then
      error = 0
      result = num[1]
    elseif character[2] == "2" then
      error = 0
      result = (num[1] + num[2]) / 2
    elseif character[2] == "3" then
      error = 0
      result = (num[1] + num[2] + num[3]) / 3
    elseif character[2] == "4" then
      error = 0
      result = (num[1] + num[2] + num[3] + num[4]) / 4
    elseif character[2] == "5" then
      error = 0
      result = (num[1] + num[2] + num[3]+ num[4] + num[5]) /5
    else
      error = 1
    end

  elseif character[1] == ">" and formula_leng == 2 then -- Maximum value of fields selected
    if character[2] == "1" then
      error = 0
      result = num[1]
    elseif character[2] == "2" then
        error = 0
        result = math.max (num[1] , num[2])
    elseif character[2] == "3" then
      result = math.max(num[1] , num[2] , num[3])
      error = 0
    elseif character[2] == "4" then
      error = 0
      result = math.max(num[1] , num[2] , num[3] , num[4])
    elseif character[2] == "5" then
      error = 0
      result = math.max(num[1] , num[2] , num[3], num[4] , num[5])
    else
      error = 1
    end

  elseif character[1] == "<" and formula_leng == 2 then -- Minimum value of fields selected
    if character[2] == "1" then
      error = 0
      result = num[1]
    elseif character[2] == "2" then
      error = 0
      result = math.min (num[1] , num[2])
    elseif character[2] == "3" then
      error = 0
      result = math.min(num[1] , num[2] , num[3])
    elseif character[2] == "4" then
      error = 0
      result = math.min(num[1] , num[2] , num[3] , num[4])
    elseif character[2] == "5" then
      error = 0
      result = math.min(num[1] , num[2] , num[3], num[4] , num[5])
    else
      error = 1
    end
  
  elseif character[1] ~= nil and tonumber(character[1]) ~= nil and tonumber(character[2]) == nil then -- Maximum value of fields selected --arirmethic operation
    print("<<< arirmethic operation >>>>")
    for value= 1, formula_leng, 1 do
      if character[value] == "1" then
        character[value] = device:get_latest_state("main", number_Field_One.ID, number_Field_One.numberFieldOne.NAME)
      elseif character[value] == "2" then
        character[value] = device:get_latest_state("main", number_Field_Two.ID, number_Field_Two.numberFieldTwo.NAME)
      elseif character[value] == "3" then
        character[value] = device:get_latest_state("main", number_Field_Three.ID, number_Field_Three.numberFieldThree.NAME)
      elseif character[value] == "4" then
        character[value] = device:get_latest_state("main", number_Field_Four.ID, number_Field_Four.numberFieldFour.NAME)
      elseif character[value] == "5" then
        character[value] = device:get_latest_state("main", number_Field_Five.ID, number_Field_Five.numberFieldFive.NAME)
      end
    end
    
    result = character[1]
    for value= 1, formula_leng, 1 do
      if math.fmod(value , 2) == 0 then
        if character[value] == "+" then
          error = 0
          result = result + character[value + 1]
        elseif character[value] == "-" then
          error = 0
          result = result - character[value + 1]
        elseif character[value] == "x" or character[value] == "X" or character[value] == "*" then
          error = 0
          result = result * character[value + 1]
        elseif character[value] == "/" or character[value] == ":" then
          error = 0
          result = result / character[value + 1]
        else
          error = 1
          break
        end
      end
    end
  elseif (character[1] == "C" or character[1] == "c") and formula_leng == 2 then -- Contador acumulable
    print ("<<< Counter calculation")

    result = device:get_field("set_result")
    if character[2] == "+" then
      result = result + num[1]
      error = 0
    elseif character[2] == "-" then
      result = result -  num[1]
      error = 0
    else
      error = 1
    end
  end

  -- emit result rounded to 2 decimal
  result = tonumber(string.format("%.2f", result)) 
  local str = "Calulating..."
  if error == 0 then
    str = "Result= ".. result .. ", Correct calculation"
  else
    result = 0
    str = "Result= ".. result ..", Incorrect text formula!"
  end
  if result > 1000000000 or result < -1000000000 then
    result = 0
    str = "Result exceeds the limits"
  end
  device:emit_event(device_Info.deviceInfo(str))
  if device.preferences.instructions == true or device.preferences.instructions == nil then
    str = device:get_field("set_device_info")
  else
    str = "Waiting new data..."
  end

  -- emit formula instructions after 5 seconds 
  local instructions_delay = device:get_field("instructions_delay")
  if instructions_delay ~= nil then
    --print("<<<<< Cancel instructions_delay >>>>>")
    driver:cancel_timer(instructions_delay)
    device:set_field("instructions_delay", nil)
  end
  if instructions_delay == nil then
    instructions_delay = device.thread:call_with_delay(5, function(d) 
      device:emit_event(device_Info.deviceInfo({value = str},{visibility = {displayed = true }}))
      device:set_field("instructions_delay", nil)
      end )
    device:set_field("instructions_delay", instructions_delay)
  end

  if device.preferences.logDebugPrint == true then
    print("<<<<< Result >>>>", result)
  end
  device:set_field("set_result", result, {persist = false})
  device:emit_event(calculation_Result.calculationResult(result))
end

--command_handlers.setNumberField_One_handler
local function setNumber_Field_One_handler(driver, device, command)
  if command.args.value ~= device:get_latest_state("main", number_Field_One.ID, number_Field_One.numberFieldOne.NAME) or
    device:get_field("set_text_formula") == "C+" or
    device:get_field("set_text_formula") == "C-" or
    device:get_field("set_text_formula") == "c+" or
    device:get_field("set_text_formula") == "c-" then
    device:emit_event(number_Field_One.numberFieldOne(command.args.value))

    if device:get_field("set_text_formula") ~= "" and device:get_field("set_text_formula") ~= "-"  then
      device.thread:call_with_delay(1, function(d) calculator(driver, device, command, device:get_field("set_text_formula")) end )
    end
  else
    device:emit_event(number_Field_One.numberFieldOne(command.args.value))
  end
end

--command_handlers.setNumberSwitch_Two_handler
local function setNumber_Field_Two_handler(driver, device, command)
  if command.args.value ~= device:get_latest_state("main", number_Field_Two.ID, number_Field_Two.numberFieldTwo.NAME) then
    device:emit_event(number_Field_Two.numberFieldTwo(command.args.value))

    if device:get_field("set_text_formula") ~= "" and device:get_field("set_text_formula") ~= "-" and
    device:get_field("set_text_formula") ~= "C+" and
    device:get_field("set_text_formula") ~= "C-" and
    device:get_field("set_text_formula") ~= "c+" and
    device:get_field("set_text_formula") ~= "c-" then
      device.thread:call_with_delay(1, function(d) calculator(driver, device, command, device:get_field("set_text_formula")) end )
    end
  else
    device:emit_event(number_Field_Two.numberFieldTwo(command.args.value))
  end
end

--command_handlers.setNumberField_Three_handler
local function setNumber_Field_Three_handler(driver, device, command)
  if command.args.value ~= device:get_latest_state("main", number_Field_Three.ID, number_Field_Three.numberFieldThree.NAME) then
    device:emit_event(number_Field_Three.numberFieldThree(command.args.value))

    if device:get_field("set_text_formula") ~= "" and device:get_field("set_text_formula") ~= "-" and
    device:get_field("set_text_formula") ~= "C+" and
    device:get_field("set_text_formula") ~= "C-" and
    device:get_field("set_text_formula") ~= "c+" and
    device:get_field("set_text_formula") ~= "c-" then
      device.thread:call_with_delay(1, function(d) calculator(driver, device, command, device:get_field("set_text_formula")) end )
    end
  else
    device:emit_event(number_Field_Three.numberFieldThree(command.args.value))
  end
end

--command_handlers.setNumberField_Four_handler
local function setNumber_Field_Four_handler(driver, device, command)
  if command.args.value ~= device:get_latest_state("main", number_Field_Four.ID, number_Field_Four.numberFieldFour.NAME) then
    device:emit_event(number_Field_Four.numberFieldFour(command.args.value))

    if device:get_field("set_text_formula") ~= "" and device:get_field("set_text_formula") ~= "-" and
    device:get_field("set_text_formula") ~= "C+" and
    device:get_field("set_text_formula") ~= "C-" and
    device:get_field("set_text_formula") ~= "c+" and
    device:get_field("set_text_formula") ~= "c-" then
      device.thread:call_with_delay(1, function(d) calculator(driver, device, command, device:get_field("set_text_formula")) end )
    end
  else
    device:emit_event(number_Field_Four.numberFieldFour(command.args.value))
  end
end

--command_handlers.setNameField_Five_handler
local function setNumber_Field_Five_handler(driver, device, command)
  if command.args.value ~= device:get_latest_state("main", number_Field_Five.ID, number_Field_Five.numberFieldFive.NAME) then
    device:emit_event(number_Field_Five.numberFieldFive(command.args.value))

    if device:get_field("set_text_formula") ~= "" and device:get_field("set_text_formula") ~= "-" and
    device:get_field("set_text_formula") ~= "C+" and
    device:get_field("set_text_formula") ~= "C-" and
    device:get_field("set_text_formula") ~= "c+" and
    device:get_field("set_text_formula") ~= "c-" then
      device.thread:call_with_delay(1, function(d) calculator(driver, device, command, device:get_field("set_text_formula")) end )
    end
  else
    device:emit_event(number_Field_Five.numberFieldFive(command.args.value))
  end
end

--command_handlers.setNumberField_Five_handler
local function setCalculationResult_handler(driver, device, command)
  local set_result = command.args.value
  device:set_field("set_result", set_result, {persist = false})
  device:emit_event(calculation_Result.calculationResult(set_result))
end

-- command_handlers.setTextFormula_handler_handler
local function setTextFormula_handler(driver, device, command)
  --print("<<< setTextFormula_handler_handler:", command.args.value)
  local set_text_formula = command.args.value
  if set_text_formula == "" then set_text_formula = "-" end
  device:set_field("set_text_formula", set_text_formula, {persist = false})
  device:emit_event(text_Formula.textFormula(set_text_formula))

  if (set_text_formula ~= "C+" and set_text_formula ~= "C-" and set_text_formula ~= "c+"  and set_text_formula ~= "c-") then
    device.thread:call_with_delay(1, function(d) calculator(driver, device, command, set_text_formula) end )
  end
end

local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })

  if device.model ~= "Virtual Number Field-5" then
    device:try_update_metadata({ model = "Virtual Number Field-5" })
    device.thread:call_with_delay(5, function() 
      print("<<<<< model= ", device.model)
    end)
  end

  -- init set_text_formula 
  local set_text_formula = device:get_latest_state("main", text_Formula.ID, text_Formula.textFormula.NAME)
  if set_text_formula == nil then 
    set_text_formula = "-"
  end
  device:set_field("set_text_formula", set_text_formula, {persist = false})
  device:emit_event(text_Formula.textFormula(set_text_formula))

  --init set_result
  local set_result = device:get_latest_state("main", calculation_Result.ID, calculation_Result.calculationResult.NAME)
  if set_result == nil then 
    device:set_field("set_result", 0, {persist = false})
    device:emit_event(calculation_Result.calculationResult(device:get_field("set_result")))
  else
    device:emit_event(calculation_Result.calculationResult(set_result))
  end 

  --- format device info
  local str = "<em style= 'font-weight: bold;'> How to use the Calculation Formula ".."</em>" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> Average Calculation".."</em>"
  str = str .. ": A Field Number: A4" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> A4".."</em>"
  str = str .. " = Average values from Field 1 to Field 4" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> Maximum value".."</em>"
  str = str .. ": > Field Number: >5" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> >5".."</em>"
  str = str .. " = Return Max value from Field 1 to Field 5" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> Minimum value".."</em>"
  str = str .. ": < Field Number: <3" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> <3".."</em>"
  str = str .. " = Return Min value from Field 1 to Field 3" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> Free Text Formula".."</em>"
  str = str .. ": Can include oprestrs + - x /" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> 2+3/1x4-5".."</em>"
  str = str .. ", Fields and operators can be repeated" .. "<BR>"
  str = str .. "Divide Operator can use  /  or  :" .. "<BR>"
  str = str .. "Multiply Operator can use  x or  X or  *" .. "<BR>"
  str = str .. "Operations performed sequentially from left" .. "<BR>"
  str = str .. "If Formula is correct, Correct calculation displayed" .. "<BR>"
  str = str .. "If Formula is incorrect, a warning will be displayed" .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> Counter".."</em>"
  str = str .. ": C or c and + or - operator: " .. "<BR>"
  str = str .."<em style= 'font-weight: bold;'> C+, C-".."</em>"
  str = str .. ": Add or Subtract Field 1 value to Result" .. "<BR>"
  str = str .. "Every time Field 1 updated then do new Counter" .. "<BR>"
  local str_out = "<table style='font-size:50%'> <tbody>".. "<tr> <th align=left>" .. "</th> <td>" .. str .. "</td></tr>"

  str_out = str_out .. "</tbody></table>"
  
  device:set_field("set_device_info", str_out, {persist = false})
  device:emit_event(device_Info.deviceInfo({value = str_out},{visibility = {displayed = true }}))
end

local function device_added(driver, device,command)
 
  if command.command == "refresh" then
    log.info("[" .. device.id .. "] Refresh Virtual Device")
  else
    log.info("[" .. device.id .. "] Adding new Virtual Device")
  end

    local cap_status = device:get_latest_state("main", number_Field_One.ID, number_Field_One.numberFieldOne.NAME)
    if cap_status == nil then
      device:emit_event(number_Field_One.numberFieldOne(0))
    end
    cap_status = device:get_latest_state("main", number_Field_Two.ID, number_Field_Two.numberFieldTwo.NAME)
    if cap_status == nil then
      device:emit_event(number_Field_Two.numberFieldTwo(0))
    end
    cap_status = device:get_latest_state("main", number_Field_Three.ID, number_Field_Three.numberFieldThree.NAME)
    if cap_status == nil then
      device:emit_event(number_Field_Three.numberFieldThree(0))
    end
    cap_status = device:get_latest_state("main", number_Field_Four.ID, number_Field_Four.numberFieldFour.NAME)
    if cap_status == nil then
      device:emit_event(number_Field_Four.numberFieldFour(0))
    end
    cap_status = device:get_latest_state("main", number_Field_Five.ID, number_Field_Five.numberFieldFive.NAME)
    if cap_status == nil then
      device:emit_event(number_Field_Five.numberFieldFive(0))
    end
    cap_status = device:get_latest_state("main", calculation_Result.ID, calculation_Result.calculationResult.NAME)
    if cap_status == nil then cap_status = 0 end
    device:emit_event(calculation_Result.calculationResult(cap_status))
    cap_status = device:get_latest_state("main", text_Formula.ID, text_Formula.textFormula.NAME)
    if cap_status == nil then cap_status = "-" end
    device:emit_event(text_Formula.textFormula(cap_status))
    local str =  "Waiting new data..."
    if device.preferences.instructions == true or device.preferences.instructions == nil then
      if device:get_field("set_device_info") ~= nil then
        str = device:get_field("set_device_info")
      end
    end
    device:emit_event(device_Info.deviceInfo({value = str},{visibility = {displayed = false }}))

    local set_text_formula = cap_status
    if (set_text_formula ~= "C+" and set_text_formula ~= "C-" and set_text_formula ~= "c+"  and set_text_formula ~= "c-" and set_text_formula ~= "-") then
      device.thread:call_with_delay(1, function(d) calculator(driver, device, command, set_text_formula) end )
    end
end



local virtual_number_fields = {
	NAME = "virtual number fields",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_added,
    },
    [number_Field_One.ID] = {
      [number_Field_One.commands.setNumberFieldOne.NAME] = setNumber_Field_One_handler
    },
    [number_Field_Two.ID] = {
      [number_Field_Two.commands.setNumberFieldTwo.NAME] = setNumber_Field_Two_handler
    },
    [number_Field_Three.ID] = {
      [number_Field_Three.commands.setNumberFieldThree.NAME] = setNumber_Field_Three_handler
    },
    [number_Field_Four.ID] = {
      [number_Field_Four.commands.setNumberFieldFour.NAME] = setNumber_Field_Four_handler
    },
    [number_Field_Five.ID] = {
      [number_Field_Five.commands.setNumberFieldFive.NAME] = setNumber_Field_Five_handler
    },
    [text_Formula.ID] = {
      [text_Formula.commands.setTextFormula.NAME] = setTextFormula_handler
    },
    [calculation_Result.ID] = {
      [calculation_Result.commands.setCalculationResult.NAME] = setCalculationResult_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
  },

  can_handle = require("virtual-number-fields.can_handle")
}
return virtual_number_fields
