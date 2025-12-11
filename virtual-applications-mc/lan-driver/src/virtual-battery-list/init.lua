-- M.Colmenarejo 2024
local capabilities = require "st.capabilities"
local log = require "log"
--local utils = require "st.utils"

local execute_Rule_Number = capabilities["legendabsolute60149.executeRuleNumber"]
local device_Name = capabilities["legendabsolute60149.deviceName"]
local battery_Level = capabilities["legendabsolute60149.batteryLevel"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]

local device_list_level = {}

local loop = {}

-- emit battery_list
local function emit_list(driver, device)
    print("<< emit list >>")

    local total_devices = device.preferences.numberOfDevices

    local str = "<em style='font-weight: bold;'> Device List and Battery Status: ".."</em>" .. "<BR>"
    str = str .. "<em style= 'font-weight: bold;'> Last Updated (local): ".."</em>" .. os.date("%Y/%m/%d %H:%M:%S", os.time() + (device.preferences.localTimeOffset * 3600)) .. "<BR>"

    --for device_num = 1, total_devices, 1 do
    local device_num = 0
    device_list_level = device:get_field("device_list_level")
    table.sort(device_list_level) -- ordena la tabla con valores level de menor a mayor
    --print("Table device_list_level >>>>>>",utils.stringify_table(device_list_level))

    -- format of value "037001Puerta Casa" = 037 is batt level, 001= value of rule trigger value, Puerta Casa = name of device
    for num, value in ipairs(device_list_level) do    
        
        -- Example format of table value "037001Puerta Casa" = 037 is batt level, 001= value of rule trigger value, Puerta Casa = name of device
        device_num = math.tointeger(tonumber(string.sub (value, 4 , 6)))
        local batt_status = tonumber(string.sub (value, 1 , 3))
        --local name = device_list_name[device_num]
        local name = string.sub (value, 7 )
        if device.preferences.logDebugPrint == true then
            print("<<<<<<<< get batt status")
            print("<< device_num:", device_num)
            print("<< device name:", name)
            print("Batt status:",batt_status)
        end
    
        if batt_status ~= nil and batt_status <= 100 then
            if tonumber(batt_status) >= 70 then
            str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. name ..": ".."</em>" .." <em style= 'color:Green;''>" .. batt_status .. " %".."</em>".. "<BR>"
            elseif tonumber(batt_status) < 70 and tonumber(batt_status) >= 50 then
            str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. name ..": ".."</em>" .." <em style= 'color:DodgerBlue;''>" .. batt_status .. " %".."</em>".. "<BR>"
            elseif tonumber(batt_status) < 50 and tonumber(batt_status) >= 35 then
            str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. name ..": ".."</em>" .." <em style= 'color:Orange;''>" .. batt_status .. " %".."</em>".. "<BR>"
            elseif tonumber(batt_status) < 35 then
            str = str .. "<em style= 'font-weight: bold;'>".."* ".. device_num.. ". ".. name ..": ".."</em>" .." <em style= 'color:Red;''>" .. batt_status .. " %".." **".."</em>".. "<BR>"
            end
        elseif batt_status == 102 then -- received level nil value
            str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. name ..": ".."</em>" .. " <em style= 'color:Red;''>".."BATT STATUS PENDING" .."</em>".. "<BR>"
        elseif batt_status == 101 then -- device no data received from rule
            str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. name ..": ".."</em>" .. " <em style= 'color:Red;''>".."RULE Data not Received" .."</em>".. "<BR>"
        end
    end

    local str_out = "<table style='font-size:55%'> <tbody>".. "<tr> <th align=left>" .. "</th> <td>" .. str .. "</td></tr>"

    str_out = str_out .. "</tbody></table>"
    device:emit_event(device_Info.deviceInfo({value = str_out},{visibility = {displayed = true }}))
end

-- added handler and recalculate batteries Stauts
local function added_handler(driver, device)
    print ("<<<< Added device and recalculate batteries status")

    local total_devices = device.preferences.numberOfDevices
    if total_devices == 0 then return end

    if total_devices == nil then total_devices = 10 end
    local device_num = device:get_field("device_num")
    if device_num == nil then 
        device_num = 0
        device:set_field("device_num", device_num)
    end
    device_num = device_num + 1
    if device_num <= total_devices then
        device:set_field("device_num", device_num)
        loop.loop_devices_data_request(driver, device)
    else
        device:set_field("device_num", 0)

        -- set the timer for next Updated
        local batteries_timer = device:get_field("batteries_timer")
        if batteries_timer ~= nil then 
            print("<<<<< Cancel batteries_timer >>>>>")
            driver:cancel_timer(batteries_timer)
            device:set_field("batteries_timer", nil)
        end

        local timer_value = device.preferences.intervalUpdateData * 60 - (math.random(15, 30) * 10)
        batteries_timer = device.thread:call_with_delay(timer_value, function(d)
            device:set_field("batteries_timer", nil)
            device:set_field("device_num", 0)
            added_handler(driver, device)              
        end)
        device:set_field("batteries_timer", batteries_timer)

        emit_list(driver, device)

        device_list_level = {}
        device:set_field("device_list_level", device_list_level)
    end
end

-- loop data request
function loop.loop_devices_data_request(driver, device)
    --print("<< loop >>")
    device:emit_event(execute_Rule_Number.executeRuleNumber(device:get_field("device_num")))
    device:set_field("data_added", 0)

    -- set the timer for next Updated
    local wait_timer = device:get_field("wait_timer")
    if wait_timer ~= nil then 
        --print("<<<<< Cancel batteries_timer >>>>>")
        driver:cancel_timer(wait_timer)
        device:set_field("wait_timer", nil)
    end

    local timer_value = 3 -- if no data received from rule then get next device
    wait_timer = device.thread:call_with_delay(timer_value, function(d)
        device:set_field("wait_timer", nil)
        local device_num = device:get_field("device_num")
        device:set_field("setDeviceName", "No Device")
        local name = device:get_field("setDeviceName")
        local rule_number = string.format("%03d", device_num)

        device_list_level = device:get_field("device_list_level")
        if device_list_level == nil then device_list_level = {} end
        device_list_level[device_num]= "101".. rule_number .. name

        device:set_field("device_list_level", device_list_level)

        added_handler(driver, device)              
    end)
    device:set_field("wait_timer", wait_timer)
end

-- write list table
local function write_list_table(driver, device)
    print("<<< write_list_table >>>")

    local wait_timer = device:get_field("wait_timer")
    if wait_timer ~= nil then 
        --print("<<<<< Cancel wait_timer >>>>>")
        driver:cancel_timer(wait_timer)
        device:set_field("wait_timer", nil)
    end

    -- Example format of table value "037001Puerta Casa" = 037 is batt level, 001= value of rule trigger value, device_num, Puerta Casa = name of device
    local device_num = device:get_field("device_num")
    local name = device:get_field("setDeviceName")
    local level = device:get_field("setBatteryLevel")
    if level == nil then level = 102 end
    level = string.format("%03d", device:get_field("setBatteryLevel"))
    local rule_number = string.format("%03d", device_num)

    device_list_level = device:get_field("device_list_level")
    if device_list_level == nil then device_list_level = {} end
    device_list_level[device_num]=  level .. rule_number .. name
    device:set_field("device_list_level", device_list_level)

    --print("Table device_list_level >>>>>>",utils.stringify_table(device_list_level))
    --level = string.sub (device_list_level[device_num], 1 , 3)
    --print("<<< level", level)

    if device_num < device.preferences.numberOfDevices then
        device.thread:call_with_delay(1, function(d)
            added_handler(driver, device)
        end)
    else
        device:set_field("device_num", 0)

        -- set the timer for next Updated
        local batteries_timer = device:get_field("batteries_timer")
        if batteries_timer ~= nil then 
            print("<<<<< Cancel batteries_timer >>>>>")
            driver:cancel_timer(batteries_timer)
            device:set_field("batteries_timer", nil)
        end

        local timer_value = device.preferences.intervalUpdateData * 60 - (math.random(15, 30) * 10)
        batteries_timer = device.thread:call_with_delay(timer_value, function(d)
            device:set_field("batteries_timer", nil)
            device:set_field("device_num", 0)
            added_handler(driver, device)              
        end)
        device:set_field("batteries_timer", batteries_timer)

        emit_list(driver, device)
        device_list_level = {}
        device:set_field("device_list_level", device_list_level)
    end
end

-- setExecuteRuleNumber_handler
local function setExecuteRuleNumber_handler(driver, device, command)
  --print("<<< setExecuteRuleNumber_handler:", command.args.value)
    device:emit_event(execute_Rule_Number.executeRuleNumber(command.args.value))
end

-- setDeviceName_handler
local function setDeviceName_handler(driver, device, command)
    --print("<<< setDeviceName_handler:", command.args.value)
    device:set_field("setDeviceName", command.args.value)
    local data_added = device:get_field("data_added") + 1
    if device.preferences.logDebugPrint == true then
        print("<<< data_added:",data_added)
    end
    device:set_field("data_added", data_added)

    device:emit_event(device_Name.deviceName(command.args.value))

    if data_added == 2 then
        write_list_table(driver, device)
    end
end

-- setBatteryLevel_handler
local function setBatteryLevel_handler(driver, device, command)
    --print("<<< setBatteryLevel_handler:", command.args.value)
    device:set_field("setBatteryLevel", command.args.value)
    local data_added = device:get_field("data_added") + 1
    if device.preferences.logDebugPrint == true then
        print("<<< data_added:",data_added)
    end
    device:set_field("data_added", data_added)

    device:emit_event(battery_Level.batteryLevel(command.args.value))

    if data_added == 2 then
        write_list_table(driver, device)
    end
end

-- preferences update
local function do_preferences(driver, device)
    for id, value in pairs(device.preferences) do
      local oldPreferenceValue = device:get_field(id)
      local newParameterValue = device.preferences[id]
      if oldPreferenceValue ~= newParameterValue then
        device:set_field(id, newParameterValue, {persist = true})
        print("<< Preference changed name:", id, "Old Value:",oldPreferenceValue, "New Value:", newParameterValue)
        if id == "numberOfDevices" then
            if device.preferences.numberOfDevices > 0 then 
              -- set the timer for next Updated
              local batteries_timer = device:get_field("batteries_timer")
              if batteries_timer ~= nil then 
                print("<<<<< Cancel batteries_timer >>>>>")
                driver:cancel_timer(batteries_timer)
                device:set_field("batteries_timer", nil)
              end
              device:set_field("device_num", 0)
              device:emit_event(execute_Rule_Number.executeRuleNumber(0))
              added_handler(driver, device)
            end
        end
      end
    end
    -- This will print in the log the total memory in use by Lua in Kbytes
    print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- added new device
local function added_device(driver, device)
log.info("[" .. device.id .. "] Adding new Virtual Device")


    local cap_status = device:get_latest_state("main", device_Info.ID, device_Info.deviceInfo.NAME)
    if cap_status == nil then
    device:emit_event(device_Info.deviceInfo({value = "Device Events List Empty"},{visibility = {displayed = false }}))
    end
    device:emit_event(execute_Rule_Number.executeRuleNumber(0))
    device:emit_event(battery_Level.batteryLevel(0))
    device:emit_event(device_Name.deviceName("-"))
    added_handler(driver, device)
end

-- refresh handler
local function device_refresh(driver, device, command)
    log.info("[" .. device.id .. "] Refresh Virtual Device")
    -- set the timer for next Updated
    local batteries_timer = device:get_field("batteries_timer")
    if batteries_timer ~= nil then 
        print("<<<<< Cancel batteries_timer >>>>>")
        driver:cancel_timer(batteries_timer)
        device:set_field("batteries_timer", nil)
    end
    device:set_field("device_num", 0)
    device:emit_event(execute_Rule_Number.executeRuleNumber(0))
    local delay = 1
    device.thread:call_with_delay(delay, function(d)
    added_handler(driver, device)
    end)
end

local function device_init(driver, device) 
    log.info("[" .. device.id .. "] Initializing Virtual Device")
  
    -- mark device as online so it can be controlled from the app
    device:online()
  
    -- provisioning_state = "PROVISIONED"
    print("doConfigure performed, transitioning device to PROVISIONED")
    device:try_update_metadata({ provisioning_state = "PROVISIONED" })

    if device.model ~= "Virtual List Batteries" then
        device:try_update_metadata({ model = "Virtual List Batteries" })
        device.thread:call_with_delay(5, function() 
          print("<<<<< model= ", device.model)
        end)
    end

    -- set the timer for next Updated
    local batteries_timer = device:get_field("batteries_timer")
    if batteries_timer ~= nil then 
        print("<<<<< Cancel batteries_timer >>>>>")
        driver:cancel_timer(batteries_timer)
        device:set_field("batteries_timer", nil)
    end
    device:set_field("device_num", 0)
    device:emit_event(execute_Rule_Number.executeRuleNumber(0))
    
    local delay = math.random (0, 4) * 15

    device.thread:call_with_delay(delay, function(d)
    added_handler(driver, device)
    end)
end

local virtual_battery_list = {
	NAME = "virtual calendar device",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_refresh,
    },
    [execute_Rule_Number.ID] = {
        [execute_Rule_Number.commands.setExecuteRuleNumber.NAME] = setExecuteRuleNumber_handler,
      },
    [device_Name.ID] = {
        [device_Name.commands.setDeviceName.NAME] = setDeviceName_handler,
    },
    [battery_Level.ID] = {
        [battery_Level.commands.setBatteryLevel.NAME] = setBatteryLevel_handler,
    },
  },
  lifecycle_handlers = {
    added = added_device,
    init = device_init,
    infoChanged = do_preferences,
  },

  can_handle = require("virtual-battery-list.can_handle")
}

return virtual_battery_list
