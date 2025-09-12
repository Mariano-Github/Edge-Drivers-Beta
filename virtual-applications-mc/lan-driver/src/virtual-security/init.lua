-- M.Colmenarejo 2024
local capabilities = require "st.capabilities"
--local utils = require "st.utils"
local log = require "log"

local old_Code = capabilities["legendabsolute60149.oldCode"]
local new_Code = capabilities["legendabsolute60149.newCode"]
local routine_Code = capabilities["legendabsolute60149.routineCode"]
local security_Status = capabilities["legendabsolute60149.securityStatus"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]

local DEVICE_CODE_AWAY
local DEVICE_CODE_STAY
local DEVICE_CODE_DISARM
local set_routine_code = "-"

local can_handle = function(opts, driver, device)
      if device.preferences.switchNumber == 13 then
        local subdriver = require("virtual-security")
        return true, subdriver
      else
        return false
      end     
end

-- print instruction to userdata
local function print_text(driver, device)
    --- format device info
    local str_out = "Waiting for Code..."
    if device.preferences.instructions == true or device.preferences.instructions == nil then
        local str = "<em style= 'font-weight: bold;'> How use Device to Change Securuty Status ".."</em>" .. "<BR>"
        str = str .."<em style= 'font-weight: bold;'> Instantaneus Security Status Change:".."</em>".. "<BR>"
        str = str .. "Change Status in Security Mode Capability," .. "<BR>"
        str = str .. "Manually or with a Routine" .. "<BR>"
        str = str .."<em style= 'font-weight: bold;'> Delayed Security Status Change:".."</em>".. "<BR>"
        str = str .. "1. You need create a different code for each Mode" .. "<BR>"
        str = str .. " - Initial Code for Mode Disarmed: 111" .. "<BR>"
        str = str .. " - Initial Code for Mode Armed Away: 222" .. "<BR>"
        str = str .. " - Initial Code for Mode Armed Stay: 333" .. "<BR>"
        str = str .. " - Select Mode to Set a New Code. Exa: Disarmed" .. "<BR>"
        str = str .. " - Write the old Code of the Mode. Example: 111" .. "<BR>"
        str = str .. " - Write the new Code of the Mode. Example: 215" .. "<BR>"
        str = str .. " - Code minimum length 3 alphanumeric characters" .. "<BR>"
        str = str .. "2. In preferences set the custom dalay for each Mode" .. "<BR>"
        str = str .. "3. Write the code for the Security Mode to Change" .. "<BR>"
        str = str .. "4. After Delay, Security Mode changed in STHM" .. "<BR>"
        str = str .. "5. Code could set with Routines:" .. "<BR>"
        str = str .. " - by pressing a muti-button secuence or" .. "<BR>"
        str = str .. " - sending code with a routine, rule or scene" .. "<BR>"
        str = str .. "<em style= 'font-weight: bold;'> Mode Codes saved can see in CLI logs:".."</em>" .. "<BR>"
        str = str .. "1. In preferences set:Show logs Debug Print in CLI" .. "<BR>"
        str = str .. "2. write any text in old Code or new Code capability" .. "<BR>"
        str_out = "<table style='font-size:50%'> <tbody>".. "<tr> <th align=left>" .. "</th> <td>" .. str .. "</td></tr>"

        str_out = str_out .. "</tbody></table>"
    end
    local visible = device.preferences.instructions
    if visible == nil then visible = false end
    device:emit_event(device_Info.deviceInfo({value = str_out},{visibility = {displayed = visible }}))
end

--check code handler
local function check_code(driver, device)
    print("<< Check_Code >>")

    local status = ""
    if device:get_field("set_code") == device:get_field("DEVICE_CODE_AWAY") then
        status ="armedAway"  
    elseif device:get_field("set_code") == device:get_field("DEVICE_CODE_STAY") then
        status ="armedStay"
    elseif device:get_field("set_code") == device:get_field("DEVICE_CODE_DISARM") then
        status ="disarmed"
    else
        device:emit_event(device_Info.deviceInfo({value = "Code Error"},{visibility = {displayed = false }}))
        device.thread:call_with_delay(1.5, function(d)
            print_text(driver, device)
        end)
        return
    end

    device:set_field("setSecurityStatus", status)
    local delay = device.preferences.armAwayDelay
    if status == "disarmed" then 
        delay = device.preferences.disarmDelay
    elseif status == "armedStay" then 
        delay = device.preferences.armStayDelay
    end
    local text = "Waiting ".. delay .. " Sec. Delay for ".. status
    device:emit_event(device_Info.deviceInfo({value = text},{visibility = {displayed = false }}))

    for timer in pairs(device.thread.timers) do
        print("<<<<< Cancel all timer >>>>>")
        device.thread:cancel_timer(timer)
    end
    device.thread:call_with_delay(delay, function(d)
        device:emit_event(capabilities.securitySystem.securitySystemStatus(device:get_field("setSecurityStatus")))
        device:emit_event(security_Status.securityStatus(device:get_field("setSecurityStatus")))
        device:set_field("set_code", "-")
        device:emit_event(routine_Code.routineCode("-"))
        device:emit_event(device_Info.deviceInfo({value = "Security System Status Updated"},{visibility = {displayed = false }}))
    end)
end

-- set_routine_handler
local function setRoutineCode_handler(driver, device, command)
    --print("<<< setRoutineCode_handler:", command.args.value)

    if device.preferences.logDebugPrint == true then
        print("<<< setRoutineCode_handler:",command.args.value)
    end
    if  set_routine_code == "-" then
        set_routine_code = command.args.value
    else
        set_routine_code =  set_routine_code .. command.args.value
    end

    device:set_field("set_code",  set_routine_code)
    device:emit_event(routine_Code.routineCode(set_routine_code))

    local wait_timer = device:get_field("wait_timer")
    if wait_timer ~= nil then 
        --print("<<<<< Cancel batteries_timer >>>>>")
        driver:cancel_timer(wait_timer)
        device:set_field("wait_timer", nil)
    end
    local timer_value = 5 -- delete write code
    wait_timer = device.thread:call_with_delay(timer_value, function(d)
        set_routine_code = "-"
        device:set_field("set_code", set_routine_code)
        device:emit_event(routine_Code.routineCode(set_routine_code))
        wait_timer = nil
    end)
    device:set_field("wait_timer", wait_timer)

    if  set_routine_code ~= "-" then
        check_code(driver, device)
    end
end


--setSecurityStatus_handler
local function setSecurityStatus_handler(driver, device, command)
    --print("<<< setSecurityStatus_handler:", command.args.value)
 
    if device.preferences.logDebugPrint == true then
     print("<<< setSecurityStatus:",command.args.value)
    end

    device:set_field("setSecurityStatus",  command.args.value, {persist = false})
    device:emit_event(security_Status.securityStatus(command.args.value))
end

 -- added new device
local function added_device(driver, device)
    log.info("[" .. device.id .. "] Adding new Virtual Device")

    device.thread:call_with_delay(3, 
    function() 
        -- set a default or required state for each capability attribute
        if device.preferences.switchNumber ~= nil then
            if device:get_field("DEVICE_CODE_AWAY") == nil then
                device:set_field("DEVICE_CODE_AWAY", "222", {persist = true})
            end
            if device:get_field("DEVICE_CODE_STAY") == nil then
                device:set_field("DEVICE_CODE_STAY", "333", {persist = true})
            end
            if device:get_field("DEVICE_CODE_DISARM") == nil then
                device:set_field("DEVICE_CODE_DISARM", "111", {persist = true})
            end
            device:emit_event(routine_Code.routineCode("-"))
            device:set_field("set_code", "-")
            
            local cap_status = device:get_latest_state("main", capabilities.securitySystem.ID, capabilities.securitySystem.securitySystemStatus.NAME)
            if cap_status == nil then
                device:emit_event(capabilities.securitySystem.securitySystemStatus("disarmed"))
                device:emit_event(security_Status.securityStatus("disarmed"))
                device:set_field("setSecurityStatus", "disarmed", {persist = false})
            else
                device:emit_event(capabilities.securitySystem.securitySystemStatus(cap_status))
                device:emit_event(security_Status.securityStatus(cap_status))
                device:set_field("setSecurityStatus", cap_status, {persist = false})
            end
            print_text(driver, device)

            device:emit_event(old_Code.oldCode("-"))
            device:emit_event(new_Code.newCode("-"))
            device:set_field("oldCode", "-")
            device:set_field("newCode", "-")

            if device.preferences.logDebugPrint == true then
                print("<<< DEVICE_CODE_AWAY:",device:get_field("DEVICE_CODE_AWAY"))
                print("<<< DEVICE_CODE_STAY:",device:get_field("DEVICE_CODE_STAY"))
                print("<<< DEVICE_CODE_DISARM:",device:get_field("DEVICE_CODE_DISARM"))
            end
        end
    end)
end

--- setSecuritySystemStatus_handler
local function setSecuritySystemStatus_handler(driver, device, command)
    if device.preferences.logDebugPrint == true then
        print("<<< setSecuritySystemStatus:", command.command)
    end

    if command.command == "disarm" then
        device:emit_event(capabilities.securitySystem.securitySystemStatus("disarmed"))
    elseif command.command == "armStay" then
        device:emit_event(capabilities.securitySystem.securitySystemStatus("armedStay"))
    elseif command.command == "armAway" then
        device:emit_event(capabilities.securitySystem.securitySystemStatus("armedAway"))
    end
    device:emit_event(device_Info.deviceInfo({value = "Security System Status Updated"},{visibility = {displayed = false }}))
    device.thread:call_with_delay(3, function(d)
        print_text(driver, device)
    end)
end

local function do_refresh(driver, device)
    added_device(driver, device)
end


--setOldCode_handler
local function setOldCode_handler(driver, device, command)
    device:set_field("oldCode", command.args.value)
    device:emit_event(old_Code.oldCode(command.args.value))

    local code_to_change =  device:get_field("DEVICE_CODE_DISARM")
    if device:get_field("setSecurityStatus") == "armedAway" then
        code_to_change = device:get_field("DEVICE_CODE_AWAY")
    elseif device:get_field("setSecurityStatus") == "armedStay" then
        code_to_change = device:get_field("DEVICE_CODE_STAY")
    end
    if code_to_change == command.args.value then
        if device:get_field("oldCode") ~= "-" and string.len(device:get_field("newCode")) >= 3 and device:get_field("oldCode") == code_to_change then
            if device:get_field("setSecurityStatus") == "armedAway" then
                if device:get_field("newCode") ~= device:get_field("DEVICE_CODE_STAY") and device:get_field("newCode") ~= device:get_field("DEVICE_CODE_DISARM") then
                    device:set_field("DEVICE_CODE_AWAY", device:get_field("newCode"), {persist = true})
                    device:emit_event(device_Info.deviceInfo({value = "New Code set " .. device:get_field("newCode")},{visibility = {displayed = false }}))
                else
                    device:emit_event(device_Info.deviceInfo({value = "Code already exists"},{visibility = {displayed = false }}))
                end
            elseif device:get_field("setSecurityStatus") == "armedStay" then
                if device:get_field("newCode") ~= device:get_field("DEVICE_CODE_AWAY") and device:get_field("newCode") ~= device:get_field("DEVICE_CODE_DISARM") then
                    device:set_field("DEVICE_CODE_STAY", device:get_field("newCode"), {persist = true})
                    device:emit_event(device_Info.deviceInfo({value = "New Code set " .. device:get_field("newCode")},{visibility = {displayed = false }}))
                else
                    device:emit_event(device_Info.deviceInfo({value = "Code already exists"},{visibility = {displayed = false }}))
                end
            elseif device:get_field("setSecurityStatus") == "disarmed" then
                if device:get_field("newCode") ~= device:get_field("DEVICE_CODE_STAY") and device:get_field("newCode") ~= device:get_field("DEVICE_CODE_AWAY") then
                    device:set_field("DEVICE_CODE_DISARM", device:get_field("newCode"), {persist = true})
                    device:emit_event(device_Info.deviceInfo({value = "New Code set " .. device:get_field("newCode")},{visibility = {displayed = false }}))
                else
                    device:emit_event(device_Info.deviceInfo({value = "Code already exists"},{visibility = {displayed = false }}))
                end
            end
            device:set_field("newCode", "-")
            device:set_field("oldCode", "-")
            device.thread:call_with_delay(3, function(d)
                print_text(driver, device)
                device:emit_event(old_Code.oldCode("-"))
                device:emit_event(new_Code.newCode("-"))
            end)
        end
    else
        device:emit_event(device_Info.deviceInfo({value = "Old Code Error"},{visibility = {displayed = false }}))
        device.thread:call_with_delay(3, function(d)
            print_text(driver, device)
            device:emit_event(old_Code.oldCode("-"))
            device:emit_event(new_Code.newCode("-"))
        end)
    end
    if device.preferences.logDebugPrint == true then
        print("<<< oldCode:",device:get_field("oldCode"))
        print("<<< newCode",device:get_field("newCode"))
        print("<<< DEVICE_CODE_AWAY:",device:get_field("DEVICE_CODE_AWAY"))
        print("<<< DEVICE_CODE_STAY:",device:get_field("DEVICE_CODE_STAY"))
        print("<<< DEVICE_CODE_DISARM:",device:get_field("DEVICE_CODE_DISARM"))
    end
end

--setNewCode_handler
local function setNewCode_handler(driver, device, command)
    device:set_field("newCode", command.args.value)
    device:emit_event(new_Code.newCode(command.args.value))

    local code_to_change =  device:get_field("DEVICE_CODE_DISARM")
    if device:get_field("setSecurityStatus") == "armedAway" then
        code_to_change = device:get_field("DEVICE_CODE_AWAY")
    elseif device:get_field("setSecurityStatus") == "armedStay" then
        code_to_change = device:get_field("DEVICE_CODE_STAY")
    end

    if string.len(device:get_field("newCode")) >= 3 and device:get_field("oldCode") == code_to_change then
        if device:get_field("setSecurityStatus") == "armedAway" then
            if device:get_field("newCode") ~= device:get_field("DEVICE_CODE_STAY") and device:get_field("newCode") ~= device:get_field("DEVICE_CODE_DISARM") then
                device:set_field("DEVICE_CODE_AWAY", command.args.value, {persist = true})
                device:emit_event(device_Info.deviceInfo({value = "New Code set " .. device:get_field("newCode")},{visibility = {displayed = false }}))
            else
                device:emit_event(device_Info.deviceInfo({value = "Code already exists"},{visibility = {displayed = false }}))
            end
        elseif device:get_field("setSecurityStatus") == "armedStay" then
            if device:get_field("newCode") ~= device:get_field("DEVICE_CODE_AWAY") and device:get_field("newCode") ~= device:get_field("DEVICE_CODE_DISARM") then
                device:set_field("DEVICE_CODE_STAY", command.args.value, {persist = true})
                device:emit_event(device_Info.deviceInfo({value = "New Code set " .. device:get_field("newCode")},{visibility = {displayed = false }}))
            else
                device:emit_event(device_Info.deviceInfo({value = "Code already exists"},{visibility = {displayed = false }}))
            end
        elseif device:get_field("setSecurityStatus") == "disarmed" then
            if device:get_field("newCode") ~= device:get_field("DEVICE_CODE_STAY") and device:get_field("newCode") ~= device:get_field("DEVICE_CODE_AWAY") then
                device:set_field("DEVICE_CODE_DISARM", command.args.value, {persist = true})
                device:emit_event(device_Info.deviceInfo({value = "New Code set " .. device:get_field("newCode")},{visibility = {displayed = false }}))
            else
                device:emit_event(device_Info.deviceInfo({value = "Code already exists"},{visibility = {displayed = false }}))
            end
        end
        device:set_field("newCode", "-")
        device:set_field("oldCode", "-")
        device.thread:call_with_delay(3, function(d)
            print_text(driver, device)
            device:emit_event(new_Code.newCode("-"))
            device:emit_event(old_Code.oldCode("-"))
        end)
    else
        device:emit_event(device_Info.deviceInfo({value = "New Code len < 3 or Old Code Error"},{visibility = {displayed = false }}))
        device.thread:call_with_delay(3, function(d)
            print_text(driver, device)
            device:emit_event(new_Code.newCode("-"))
            device:emit_event(old_Code.oldCode("-"))
        end)
    end
    if device.preferences.logDebugPrint == true then
        print("<<< oldCode:",device:get_field("oldCode"))
        print("<<< newCode",device:get_field("newCode"))
        print("<<< DEVICE_CODE_AWAY:",device:get_field("DEVICE_CODE_AWAY"))
        print("<<< DEVICE_CODE_STAY:",device:get_field("DEVICE_CODE_STAY"))
        print("<<< DEVICE_CODE_DISARM:",device:get_field("DEVICE_CODE_DISARM"))
    end
end

local virtual_security_device = {
	NAME = "virtual security device",
    capability_handlers = {
      [capabilities.refresh.ID] = {
        [capabilities.refresh.commands.refresh.NAME] = do_refresh,
      },
      [routine_Code.ID] = {
        [routine_Code.commands.setRoutineCode.NAME] = setRoutineCode_handler
      },
      [security_Status.ID] = {
        [security_Status.commands.setSecurityStatus.NAME] = setSecurityStatus_handler
      },
      [capabilities.securitySystem.ID] = {
        [capabilities.securitySystem.commands.armStay.NAME] = setSecuritySystemStatus_handler,
        [capabilities.securitySystem.commands.armAway.NAME] = setSecuritySystemStatus_handler,
        [capabilities.securitySystem.commands.disarm.NAME] = setSecuritySystemStatus_handler
      },
      [old_Code.ID] = {
        [old_Code.commands.setOldCode.NAME] = setOldCode_handler
      },
      [new_Code.ID] = {
        [new_Code.commands.setNewCode.NAME] = setNewCode_handler
      },
    },
    lifecycle_handlers = {
      added = added_device,
      init = added_device,
    },
	can_handle = can_handle
}

return virtual_security_device


