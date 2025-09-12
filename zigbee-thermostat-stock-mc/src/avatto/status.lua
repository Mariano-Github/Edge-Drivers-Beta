--local utils = require "st.utils"

local status = {}

--[[local statusTable = {
  temperatureCorrection = 0.0,
  localTimeOffset = 1,
  selectedSensor = 0,
  maxTemperature= 60.0,
  hysteresis = 1.0,
  frostProtection = false,
  schedeule = DEFAULT_SCHEDULE,
}]]

local function split(str, sep)
  local t = {}
  for s in string.gmatch(str, "([^" .. sep .. "]+)") do
    table.insert(t, s)
  end
  return t
end

function status:checkScheduleString(scheduleString)
  if scheduleString == nil or scheduleString == "" then return false end
  local ps = split(scheduleString, ";")
  if ps == nil or #ps ~= 8 then return false end
  for i= 1, 8 do
    ps[i] = ps[i]:match("^%s*(.-)%s*$")  -- trim() each part 
    local sp = split(ps[i], " ")        -- split time and temp
    if sp == nil or #sp ~= 2 then return false end
    local time = split(sp[1],":")
    if time == nil or #time ~= 2 then return false end
    local hour = tonumber(time[1])
    local minute = tonumber(time[2])
    local temp = tonumber(string.format("%.1f", sp[2]))
    if hour < 0 or hour > 23 or minute < 0 or minute > 59 or temp < 5 or temp > 35 then
      return false
    end
  end
  return true -- Only if all pairs time/temp are ok we return true
end


local function getPeriodString(period)
  local hour = string.unpack("b", string.sub(period, 1, 1))
  local minute = string.unpack("b", string.sub(period, 2, 2))
  local temp = string.unpack(">I2", string.sub(period, 3, 4)) / 10
  return string.format("%02d", hour) .. ":" .. string.format("%02d", minute) .. " " .. string.format("%.1f",temp) --.. "ºC"
end

function status:getScheduleArray(programs)
  local periodArray = {}
  local p = 0
  for i = 1, 8 do
    periodArray[i] = getPeriodString(string.sub(programs, p + 1, p + 4))
    p = p + 4
  end
  return periodArray
end

return status
