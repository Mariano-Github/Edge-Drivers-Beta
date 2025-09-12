-- M.Colmenarejo 2024
local capabilities = require "st.capabilities"
local utils = require "st.utils"
local log = require "log"

local device_Event = capabilities["legendabsolute60149.deviceEvent"]
local device_Name = capabilities["legendabsolute60149.deviceName"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]

local device_list = {}

local can_handle = function(opts, driver, device)
    if device.preferences.switchNumber == 12 then
      local subdriver = require("virtual-events-list")
      return true, subdriver
    else
      return false
    end  
  end

-- emit battery_list
local function emit_list(driver, device)
    --print("<< emit list >>")

    local total_events = device.preferences.numberOfEvents
    local str = "Device Events List Empty"
    if total_events > 0 then
        str = "Waiting for Device Events"
        local device_num = device:get_field("device_num")
        if device_num > 0 then
            str = "<em style='font-weight: bold;'> Devices Events: ".."</em>" .. "<BR>"
            str = str .. "<em style= 'font-weight: bold;'> Last Updated (local): ".."</em>" .. os.date("%Y/%m/%d %H:%M:%S", os.time() + (device.preferences.localTimeOffset * 3600)) .. "<BR>"
        end
        local number = 0
        device_list = device:get_field("device_list")
        --table.sort(device_list, device_num) -- ordena la tabla con valores level de menor a mayor
        if device.preferences.logDebugPrint == true then
            print("Table device_list_level >>>>>>",utils.stringify_table(device_list))
        end

        for num = device_num, 1, -1 do  
            local value = device_list[num]
            -- Example format of table value "Feb/12 19:27:01> Puerta Casa: open" 
            number = number + 1
            if device.preferences.logDebugPrint == true then
                print("<< num:", number)
                print("<< value:", value)
            end  
            --str = str .. "<em style= 'font-weight: bold;'>".. number.. ". ".. "</em>" .. value .. "<BR>"
            if value ~= nil then
                str = str .. "<em" .. "</em>".. value .. "</em>".. "<BR>"
            end
        end
    end
    local str_out = "<table style='font-size:50%'> <tbody>".. "<tr> <th align=left>" .. "</th> <td>" .. str .. "</td></tr>"
    if str == "Waiting for Device Events" or str == "Device Events List Empty" then
        device:emit_event(device_Info.deviceInfo({value = str},{visibility = {displayed = true }}))
    else
        str_out = str_out .. "</tbody></table>"
        device:emit_event(device_Info.deviceInfo({value = str_out},{visibility = {displayed = true }}))
    end
end


-- write list table
local function write_list_table(driver, device)
    print("<<< write_list_table >>>")

    -- Example format of table value "Feb/12 12:22:20> Lidl Plug: On" = event_time .. "> " .. name .. ": " .. event
    local total_events = device.preferences.numberOfEvents
    if total_events > 0 then
        local device_num = device:get_field("device_num") + 1
        if device_num > total_events + 1 then device_num = total_events + 1 end
        device:set_field("device_num", device_num, {persist = true})

        local name = device:get_field("setDeviceName")
        local event = device:get_field("setDeviceEvent")
        local event_time = os.date("%b/%d %H:%M:%S",os.time() + (device.preferences.localTimeOffset * 3600))
        local new_data = event_time .. "> " .. name .. ": " .. event
        print("<<<< new_data", new_data)

        device_list = device:get_field("device_list")
        if device_list == nil then device_list = {} end
        --print("Table device_list >>>>>>",utils.stringify_table(device_list))
        device_list[device_num] = new_data

        --print("Table device_list >>>>>>",utils.stringify_table(device_list))
        --table.insert(device_list, new_data) -- not work

        -- move list and delete last event
        if device_list[total_events + 1] ~= nil then
            for num = 2, total_events + 1, 1 do
                device_list[num-1] = device_list[num]
            end
            device_list[total_events + 1] = nil
            device:set_field("device_num", device_num-1, {persist = true})
        end

        device:set_field("device_list", device_list, {persist = true})

        --print("Table device_list >>>>>>",utils.stringify_table(device_list))

        emit_list(driver, device)
    end
    device:set_field("data_added", 0)
end

-- added handler and recalculate batteries Stauts
local function added_handler(driver, device)
    print ("<<<< Added device events list")

    local cap_status = device:get_latest_state("main", device_Name.ID, device_Name.deviceName.NAME) 
    if cap_status == nil then
        device:emit_event(device_Name.deviceName("-"))
    end
    cap_status = device:get_latest_state("main", device_Event.ID, device_Event.deviceEvent.NAME)
    if cap_status == nil then
        device:emit_event(device_Event.deviceEvent("-"))
    end

    local total_events = device.preferences.numberOfEvents

    if total_events == nil then total_events = 50 end
    local device_num = device:get_field("device_num")
    --print("<<< device_num =",device_num)
    if device_num == nil then 
        device_num = 0
        device:set_field("device_num", device_num, {persist = true})
    end
    if device_num > total_events then
        local delete_events = device_num - total_events
        for num = 1, total_events, 1 do  -- move table positions the number of deleted events to delete olders events
            device_list[num] = device_list[delete_events + num]
        end
        for num = total_events + 1, device_num, 1 do -- delete events from new total events + 1 to end
            device_list[num] = nil
        end
        device:set_field("device_list", device_list, {persist = true})
        device_num = total_events
        device:set_field("device_num", device_num, {persist = true})
    end

    local data_added = 0
    device:set_field("data_added", data_added)
    if device.preferences.logDebugPrint == true then
        print("<<< data_added:",data_added)
        print("<<< device_num =",device_num)
    end

    device_list = device:get_field("device_list")
    if total_events == 0 or device_list == nil or device_list == {} then 
        device_list = {}
        device_num = 0 
        device:set_field("device_num", device_num, {persist = true})
        device:set_field("device_list", device_list, {persist = true})
    end

    --print("Table device_list >>>>>>",utils.stringify_table(device_list))
    emit_list(driver, device)
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

-- setDeviceEvent_handler
local function setDeviceEvent_handler(driver, device, command)
    --print("<<< setDeviceEvent_handler:", command.args.value)
    device:set_field("setDeviceEvent", command.args.value)
    local data_added = device:get_field("data_added") + 1
    if device.preferences.logDebugPrint == true then
        print("<<< data_added:",data_added)
    end
    device:set_field("data_added", data_added)

    device:emit_event(device_Event.deviceEvent(command.args.value))

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
        if id == "numberOfEvents" then
            added_handler(driver, device)
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
        device:emit_event(device_Info.deviceInfo({value = "Waiting for Device Events"},{visibility = {displayed = false }}))
      end
      added_handler(driver, device)
end

local virtual_events_list = {
	NAME = "virtual events device",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = added_handler,
    },
    [device_Event.ID] = {
        [device_Event.commands.setDeviceEvent.NAME] = setDeviceEvent_handler,
    },
    [device_Name.ID] = {
        [device_Name.commands.setDeviceName.NAME] = setDeviceName_handler,
    },
  },
  lifecycle_handlers = {
    added = added_device,
    init = added_device,
    infoChanged = do_preferences,
  },

  can_handle = can_handle
}
return virtual_events_list
