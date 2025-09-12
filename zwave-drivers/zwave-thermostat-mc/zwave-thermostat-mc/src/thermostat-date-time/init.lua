-- Copyright 2022 SmartThings
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
local log = require "log"

local TimeParameters = (require "st.zwave.CommandClass.TimeParameters")({version=1})
--local Time = (require "st.zwave.CommandClass.Time")({version=1})

local thermostat_Time = capabilities["legendabsolute60149.thermostatTime"]


local TIME_THERMOSTAT_FINGERPRINTS = {
    { manufacturerId = 0x015F, productType = 0x0712, productId = 0x5102 }, -- MCO Thermostat
    { manufacturerId = 0x015F, productType = 0x0702, productId = 0x5102 }, -- MCO Thermostat

}

local function can_handle_thermostat_heating_battery(opts, driver, device, cmd, ...)
    for _, fingerprint in ipairs(TIME_THERMOSTAT_FINGERPRINTS) do
        if device:id_match( fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
            local subdriver = require("thermostat-date-time")
            return true, subdriver
        end
    end

    return false
end


local function TimeParameters_report_handler(driver, device, command)
    print("<<< TimeParameters_report_handler >>>")
    local hour = string.format("%02d",command.args.hour_utc)
    local minute = string.format("%02d",command.args.minute_utc)
    local thermostat_local_time = hour .. ":" .. minute
    --print("<<< thermostat_time:", thermostat_local_time)
    device:emit_event(thermostat_Time.thermostatTime({value = thermostat_local_time}, {visibility = { displayed = false }}))

    local local_time = os.time() + device.preferences.localTimeOffset * 3600
    if device:get_field("last_time_Updated") == nil then device:set_field("last_time_Updated", os.time() - 45000) end
    if os.time() - device:get_field("last_time_Updated") >= 43200 then
        device:set_field("last_time_Updated", os.time() + (math.random(1, 50) * 30)) -- for different periodic time update in every device
        local hour_utc = tonumber(os.date("%H",local_time))
        local minute_utc = tonumber(os.date("%M",local_time))
        local second_utc = tonumber(os.date("%S",local_time))
        local year = tonumber(os.date("%Y",local_time))
        local month = tonumber(os.date("%m",local_time))
        local day = tonumber(os.date("%d",local_time))
        log.info("<<< TimeParameters_Set: ".. year.. "/"..month.."/".. day.. "  ".. hour_utc ..":" .. minute_utc ..":" .. second_utc)
        device:send(TimeParameters:Set({hour_utc=hour_utc, minute_utc=minute_utc, second_utc=second_utc, year=year, month=month, day=day}))

        local read_time = function()
            device:send(TimeParameters:Get({}))
        end

        device.thread:call_with_delay(1, read_time)
    end
    
end


local function device_init(self, device)
    print("<<<< GET Thermostat Date & Time>>>>>")
    device:send(TimeParameters:Get({}))
    --device:send(Time:Get({}))
    --device:send(Time:DateGet({}))
    --device:send(Time:OffsetGet({}))

    ---- Timers Cancel ------
    for timer in pairs(device.thread.timers) do
        print("<<<<< Cancel all timer >>>>>")
        device.thread:cancel_timer(timer)
    end

    ------ Timer time get activation
    device.thread:call_on_schedule(
    60,
    function ()
        --print("<< Timer Get Time >> ")
        device:send(TimeParameters:Get({}))
    end)
end


local thermostat_date_time = {
    NAME = "Thermostat-date-time",
    zwave_handlers = {
        [cc.TIME_PARAMETERS] = {
            [TimeParameters.REPORT] = TimeParameters_report_handler
        },
    },
    lifecycle_handlers = {
        init = device_init,
    },
    can_handle = can_handle_thermostat_heating_battery
}

return thermostat_date_time
