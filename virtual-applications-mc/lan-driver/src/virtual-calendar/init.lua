---- M. Colmenarejio 2022
-- require st provided libraries
local capabilities = require "st.capabilities"
local log = require "log"

-- require custom handlers from driver package
local sunrise_sunset = require "virtual-calendar.sunrise-sunset"
local sun_position = require "virtual-calendar.sun-position"

--- Custom Capabilities
local sun_Set = capabilities["legendabsolute60149.sunSet"]
local sun_Rise = capabilities["legendabsolute60149.sunRise"]
local day_Length = capabilities["legendabsolute60149.dayLength"]
local sun_Set_Offset = capabilities["legendabsolute60149.sunSetOffset1"]
local sun_Rise_Offset = capabilities["legendabsolute60149.sunRiseOffset1"]
local local_Date = capabilities["legendabsolute60149.localDate"]
local local_Day = capabilities["legendabsolute60149.localDay"]
local local_Day_Two = capabilities["legendabsolute60149.localDayTwo"]
local local_Month = capabilities["legendabsolute60149.localMonth"]
local local_Month_Two = capabilities["legendabsolute60149.localMonthTwo"]
local local_Year = capabilities["legendabsolute60149.localYear"]
local local_Hour = capabilities["legendabsolute60149.localHour"]
local local_Hour_Two = capabilities["legendabsolute60149.localHourTwo"]
local local_Date_One = capabilities["legendabsolute60149.localDateOne"]
local local_Date_Two = capabilities["legendabsolute60149.localDateTwo1"]
local local_Month_Day_One = capabilities["legendabsolute60149.localMonthDayOne"]
local local_Month_Day_Two = capabilities["legendabsolute60149.localMonthDayTwo"]
local even_Odd_Day = capabilities["legendabsolute60149.evenOddDay"]
local local_Hour_Offset = capabilities["legendabsolute60149.localHourOffset"]
local current_Time_Period = capabilities["legendabsolute60149.currentTimePeriod"]
local sun_Azimuth_Angle = capabilities["legendabsolute60149.sunAzimuthAngle"]
local sun_Elevation_Angle = capabilities["legendabsolute60149.sunElevationAngle"]
local current_Twilight = capabilities["legendabsolute60149.currentTwilight"]
local local_Week_Day = capabilities["legendabsolute60149.localWeekDay"]

local offset

-----------------------------------------------------------------
-- local functions
-----------------------------------------------------------------

--reference time to sunset and sunrise
local function time_ref(device)

      local day_change = 0
      local localHour= os.date("%H",os.time() + (offset * 3600))
      local localMinutes= tonumber(os.date("%M",os.time()))
      -- print("localHour, localMinutes =,localSecond=", localHour, localMinutes,localSecond)
      if offset > 0 then
         -- if LOCAL hour = new day calculate offset for local time
          if tonumber(localHour) < offset then
            day_change = 24 * 3600
          end
      elseif offset < 0 then
        -- if UTC hour = new day calculate offset for local time
          if tonumber(os.date("%H",os.time())) < math.abs(offset) then
            day_change = 24 * 3600 * -1
          end
      end
          local sun_rise_ref =  (os.time() +  offset * 3600)- (device:get_field("rise_time") + day_change)
          local sun_set_ref =  (os.time() +  offset * 3600)- (device:get_field("set_time") + day_change)
          --print("<<< hora actual >>>>",(os.date(os.time() +  offset * 3600)),os.date("%H:%M:%S",(os.date(os.time() +  offset * 3600))))
          --print("<<< device:get_field(rise_time)",device:get_field("rise_time"),os.date("%m/%d/%Y %H:%M:%S",device:get_field("rise_time")))
          --print("<<< device:get_field(set_time)",device:get_field("set_time"),os.date("%m/%d/%Y %H:%M:%S",device:get_field("set_time")))

          if device.preferences.logDebugPrint == true then
            print("<<< day_change",day_change/3600)
            print("<<<< sun_rise_Offset:", math.floor(sun_rise_ref / 60),"Min")
            print("<<<< sun_set_offset:", math.floor(sun_set_ref / 60),"Min")
          end

          local event_state = sun_Rise_Offset.sunRiseOffset({value = math.floor(sun_rise_ref / 60) }, { visibility = { displayed = false } })
          device:emit_event(event_state)

          event_state = sun_Set_Offset.sunSetOffset({value = math.floor(sun_set_ref / 60) }, { visibility = { displayed = false } })
          device:emit_event(event_state)

          local time = os.time() + offset * 3600

          local event = os.date("%Y/%m/%d  %H:%M",time)
          device:emit_event(local_Date.localDate({value = event}, {visibility = { displayed = false }}))

          event_state = tonumber(os.date("%H%M",time))
          device:emit_event(local_Hour.localHour({value = event_state}, {visibility = { displayed = false }}))
          device:emit_event(local_Hour_Two.localHourTwo({value = event_state}, {visibility = { displayed = false }}))

          --- Emit events every 30 minutes
          if localMinutes == 0 or localMinutes == 1 or localMinutes == 30 then

            event_state = tonumber(os.date("%d",time))
            device:emit_event(local_Day.localDay({value = event_state}, {visibility = { displayed = false }}))
            device:emit_event(local_Day_Two.localDayTwo({value = event_state}, {visibility = { displayed = false }}))

            if math.fmod(tonumber(os.date("%d",time)) , 2) == 0 then
              event = "Even"
            else
              event = "Odd"
            end
            device:emit_event(even_Odd_Day.evenOddDay({value = event}, {visibility = { displayed = false }}))

            event_state = tonumber(os.date("%m%d",time))
            device:emit_event(local_Month_Day_One.localMonthDayOne({value = event_state}, {visibility = { displayed = false }}))
            device:emit_event(local_Month_Day_Two.localMonthDayTwo({value = event_state}, {visibility = { displayed = false }}))

            event_state = tonumber(os.date("%Y%m%d",time))
            device:emit_event(local_Date_One.localDateOne({value = event_state}, {visibility = { displayed = false }}))
            device:emit_event(local_Date_Two.localDateTwo({value = event_state}, {visibility = { displayed = false }}))
            
            --if tonumber(localHour) == 0  then
              event_state = tonumber(os.date("%m",time))
              device:emit_event(local_Month.localMonth({value = event_state}, {visibility = { displayed = false }}))
              device:emit_event(local_Month_Two.localMonthTwo({value = event_state}, {visibility = { displayed = false }}))

              event_state = tonumber(os.date("%Y",time))
              device:emit_event(local_Year.localYear({value = event_state}, {visibility = { displayed = false }}))

              event_state = tonumber(os.date("%w",time))
              device:emit_event(local_Week_Day.localWeekDay({value = event_state}, {visibility = { displayed = false }}))

              event_state = offset
              if event_state == nil then
                device:set_field("setLocalHourOffset", 0, {persist = false})
                event_state = 0
              end
              device:emit_event(local_Hour_Offset.localHourOffset({value = event_state, unit = "hr"}, {visibility = { displayed = false }}))
            --end
        end
end

-- this is called once a device is added by the cloud and synchronized down to the hub
local function device_added(driver, device)
  --log.info("[" .. device.id .. "] Adding new Virtual Calendar device")

    ---- Timers Cancel ------
    for timer in pairs(device.thread.timers) do
      print("<<<<< Cancel all timer >>>>>")
      device.thread:cancel_timer(timer)
      end
      
      offset = device:get_latest_state("main", local_Hour_Offset.ID, local_Hour_Offset.localHourOffset.NAME)
      --print("<<<< offset",offset)
      if offset == nil then
        offset = device:get_field("setLocalHourOffset")
      end

      if offset == nil then
        device:set_field("setLocalHourOffset", 0, {persist = false})
        offset = 0
      end
      local lat, long = device.preferences.localLatitude, device.preferences.localLongitude --, device.preferences.localTimeOffset
      local rise_time, set_time, length_Hrs, length_Min = 0,0,0,0
      rise_time, set_time, length_Hrs, length_Min = sunrise_sunset.get(device,lat, long, offset)
      device:set_field("rise_time", rise_time, {persist = false})
      device:set_field("set_time", set_time, {persist = false})

      if device.preferences.logDebugPrint == true then
        print(" <<<",rise_time, set_time, length_Hrs, length_Min,">>>")
        print(" <<<",os.date("Sunrise: %m/%d/%Y %H:%M:%S",rise_time), os.date("Sunset: %m/%d/%Y %H:%M:%S",set_time), "Day Duration: ", length_Hrs, "Hrs",length_Min,"Min >>>")
      end

      local rise_event = os.date("%H:%M:%S",rise_time)
      device:emit_event(sun_Rise.sunRise(rise_event))

      local set_event = os.date("%H:%M:%S",set_time)
      device:emit_event(sun_Set.sunSet(set_event))

      local day_event = length_Hrs.." hrs "..(length_Min).." min"
      device:emit_event(day_Length.dayLength(day_event))

      -- Emit event firstime for events emitted every hour
      local time = os.time() + offset * 3600

      local event_state = tonumber(os.date("%H%M",time))
      device:emit_event(local_Hour.localHour({value = event_state}, {visibility = { displayed = false }}))
      device:emit_event(local_Hour_Two.localHourTwo({value = event_state}, {visibility = { displayed = false }}))

      event_state = tonumber(os.date("%d",time))
      device:emit_event(local_Day.localDay({value = event_state}, {visibility = { displayed = false }}))
      device:emit_event(local_Day_Two.localDayTwo({value = event_state}, {visibility = { displayed = false }}))

      local event = ""
      if math.fmod(tonumber(os.date("%d",time)) , 2) == 0 then
        event = "Even"
      else
        event = "Odd"
      end
      device:emit_event(even_Odd_Day.evenOddDay({value = event}, {visibility = { displayed = false }}))

      event_state = tonumber(os.date("%m%d",time))
      device:emit_event(local_Month_Day_One.localMonthDayOne({value = event_state}, {visibility = { displayed = false }}))
      device:emit_event(local_Month_Day_Two.localMonthDayTwo({value = event_state}, {visibility = { displayed = false }}))

      event_state = tonumber(os.date("%Y%m%d",time))
      device:emit_event(local_Date_One.localDateOne({value = event_state}, {visibility = { displayed = false }}))
      device:emit_event(local_Date_Two.localDateTwo({value = event_state}, {visibility = { displayed = false }}))
      

      event_state = tonumber(os.date("%m",time))
      device:emit_event(local_Month.localMonth({value = event_state}, {visibility = { displayed = false }}))
      device:emit_event(local_Month_Two.localMonthTwo({value = event_state}, {visibility = { displayed = false }}))

      event_state = tonumber(os.date("%Y",time))
      device:emit_event(local_Year.localYear({value = event_state}, {visibility = { displayed = false }}))

      event_state = tonumber(os.date("%w",time))
      device:emit_event(local_Week_Day.localWeekDay({value = event_state}, {visibility = { displayed = false }}))

      event_state = offset
      if event_state == nil then
        device:set_field("setLocalHourOffset", 0, {persist = false})
        event_state = 0
      end
      device:emit_event(local_Hour_Offset.localHourOffset({value = event_state, unit = "hr"}, {visibility = { displayed = false }}))

      --goto calculate time ref
      time_ref(device)

      -- goto sun_position
      local altitude, azimuth = sun_position.getSunPos(device, lat, long, os.time())
      if device.preferences.logDebugPrint == true then
        print("<<<<<<< Sun Altitud >>>>",altitude)
        print("<<<<<<< Sun Azimuth >>>>",azimuth)
      end
      device:emit_event(sun_Azimuth_Angle.sunAzimuthAngle({value = tonumber(string.format("%.1f",azimuth)), unit = "º"}, {visibility = { displayed = false }}))
      device:emit_event(sun_Elevation_Angle.sunElevationAngle({value = tonumber(string.format("%.1f",altitude)), unit = "º"}, {visibility = { displayed = false }}))
      if altitude < 0 and altitude > -6 and  device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "Civil-Twilight" then
        device:emit_event(current_Twilight.currentTwilight("Civil-Twilight", {visibility = { displayed = true }}))
      elseif altitude <= -6 and altitude > -12 and  device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "Nautical-Twilight" then
        device:emit_event(current_Twilight.currentTwilight("Nautical-Twilight", {visibility = { displayed = true }}))
      elseif altitude <= -12 and altitude > -18 and  device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "Astronomical-Twilight" then
        device:emit_event(current_Twilight.currentTwilight("Astronomical-Twilight", {visibility = { displayed = true }}))
      elseif altitude <= -18 and device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "None" then
        device:emit_event(current_Twilight.currentTwilight("None", {visibility = { displayed = true }}))
      elseif altitude <= 0 and  device:get_latest_state("main", current_Time_Period.ID, current_Time_Period.currentTimePeriod.NAME) ~= "Night" then
        device:emit_event(current_Time_Period.currentTimePeriod("Night", {visibility = { displayed = true }}))
      elseif altitude > 0 and  device:get_latest_state("main", current_Time_Period.ID, current_Time_Period.currentTimePeriod.NAME) ~= "Day" then
        device:emit_event(current_Time_Period.currentTimePeriod("Day", {visibility = { displayed = true }}))
        device:emit_event(current_Twilight.currentTwilight("None", {visibility = { displayed = true }}))
      end

  ------ Timer activation
  local time_sync = 60
  local local_seconds = tonumber(os.date("%S",os.time() + offset * 3600))
  time_sync = (60 - local_seconds) +  math.random(0,5)

  if device.preferences.logDebugPrint == true then
    print("<<< time_sync >>>",time_sync)
  end

  device.thread:call_with_delay(time_sync, function(d)

    --goto calculate time ref
    offset = device:get_field("setLocalHourOffset")
    if offset == nil then
      device:set_field("setLocalHourOffset", 0, {persist = false})
      offset = 0
    end
    time_ref(device)

    device.thread:call_on_schedule(
      60,
    function ()
      offset = device:get_field("setLocalHourOffset")
      if offset == nil then
        device:set_field("setLocalHourOffset", 0, {persist = false})
        offset = 0
      end
      lat, long = device.preferences.localLatitude, device.preferences.localLongitude --, device.preferences.localTimeOffset
      local localMinutes= os.date("%M",os.time() + offset * 3600)
      if tonumber(localMinutes) >= 0 and tonumber(localMinutes) <= 3 then
        rise_time, set_time, length_Hrs, length_Min = 0,0,0,0
        rise_time, set_time, length_Hrs, length_Min = sunrise_sunset.get(device, lat, long, offset)
        device:set_field("rise_time", rise_time, {persist = false})
        device:set_field("set_time", set_time, {persist = false})
        --sunrise_sunset.get(lat, long, offset)
        if device.preferences.logDebugPrint == true then
          print(" <<<",rise_time, set_time, length_Hrs, length_Min,">>>")
          print(" <<<",os.date("Sunrise: %H:%M:%S",rise_time), os.date("Sunset: %H:%M:%S",set_time), "Day Duration: ", length_Hrs, "Hrs",length_Min * 60,"Min >>>")
        end

        rise_event = os.date("%H:%M:%S",rise_time)
        device:emit_event(sun_Rise.sunRise(rise_event))

        set_event = os.date("%H:%M:%S",set_time)
        device:emit_event(sun_Set.sunSet(set_event))

        day_event = length_Hrs.." hrs "..(length_Min).." min"
        device:emit_event(day_Length.dayLength(day_event))

      end
      -- calculate offsets
      time_ref(device)

      -- goto sun_position
      altitude, azimuth = sun_position.getSunPos(device, lat, long, os.time())
      if device.preferences.logDebugPrint == true then
        print("<<<<<<< Sun Altitud >>>>",altitude)
        print("<<<<<<< Sun Azimuth >>>>",azimuth)
      end
      device:emit_event(sun_Azimuth_Angle.sunAzimuthAngle({value = tonumber(string.format("%.1f",azimuth)), unit = "º"}, {visibility = { displayed = false }}))
      device:emit_event(sun_Elevation_Angle.sunElevationAngle({value = tonumber(string.format("%.1f",altitude)), unit = "º"}, {visibility = { displayed = false }}))
      if altitude < 0 and altitude > -6 and  device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "Civil-Twilight" then
        device:emit_event(current_Twilight.currentTwilight("Civil-Twilight", {visibility = { displayed = true }}))
      elseif altitude <= -6 and altitude > -12 and  device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "Nautical-Twilight" then
        device:emit_event(current_Twilight.currentTwilight("Nautical-Twilight", {visibility = { displayed = true }}))
      elseif altitude <= -12 and altitude > -18 and  device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "Astronomical-Twilight" then
        device:emit_event(current_Twilight.currentTwilight("Astronomical-Twilight", {visibility = { displayed = true }}))
      elseif altitude <= -18 and device:get_latest_state("main", current_Twilight.ID, current_Twilight.currentTwilight.NAME) ~= "None" then
        device:emit_event(current_Twilight.currentTwilight("None", {visibility = { displayed = true }}))
      elseif altitude <= 0 and  device:get_latest_state("main", current_Time_Period.ID, current_Time_Period.currentTimePeriod.NAME) ~= "Night" then
        device:emit_event(current_Time_Period.currentTimePeriod("Night", {visibility = { displayed = true }}))
      elseif altitude > 0 and  device:get_latest_state("main", current_Time_Period.ID, current_Time_Period.currentTimePeriod.NAME) ~= "Day" then
        device:emit_event(current_Time_Period.currentTimePeriod("Day", {visibility = { displayed = true }}))
        device:emit_event(current_Twilight.currentTwilight("None", {visibility = { displayed = true }}))
      end
    end
    ,'Refresh time ref')
  end)
end

 -- added new device
 local function added_device(driver, device)
  log.info("[" .. device.id .. "] Adding new Virtual Device")

  device.thread:call_with_delay(3, 
  function()
    device_added(driver, device)
  end)
end


-- refresh handler
local function device_refresh(driver, device, command)
  device_added(driver, device)
end

-- preferences update
local function do_preferences(driver, device, event, args)
  for id, value in pairs(device.preferences) do
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:", id, "Old Value:",oldPreferenceValue, "New Value:", newParameterValue)
      if id == "localLatitude" or id == "localLongitude" then
        device_added(driver, device)
      end
    end
  end
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

--local_Hour_Offset_handler
local function local_hour_offset_handler(driver, device, command)
  --print("<<<<<<< local hour calendar >>>>>>>>")
  device:set_field("setLocalHourOffset", command.args.value, {persist = false})
  device:emit_event(local_Hour_Offset.localHourOffset({value = command.args.value,  unit = "hr"}))
    local query = function()
      device_added(driver, device)
    end
    device.thread:call_with_delay(2, query)
end

local function device_init(driver, device) 
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })

  if device.model ~= "Virtual Calendar" then
    device:try_update_metadata({ model = "Virtual Calendar" })
    device.thread:call_with_delay(5, function() 
      print("<<<<< model= ", device.model)
    end)
  end

  --initialize local hour
  local cap_status = device:get_latest_state("main", local_Hour_Offset.ID, local_Hour_Offset.localHourOffset.NAME)
  if cap_status == nil then 
    cap_status = 0 
    device:emit_event(local_Hour_Offset.localHourOffset({value = cap_status,  unit = "hr"}))
  end
  device:set_field("setLocalHourOffset",cap_status, {persist = false})

  device_added(driver, device)

end

local virtual_calendar = {
	NAME = "virtual calendar device",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_refresh,
    },
    [local_Hour_Offset.ID] = {
      [local_Hour_Offset.commands.setLocalHourOffset.NAME] = local_hour_offset_handler,
    },
  },
  lifecycle_handlers = {
    added = added_device,
    init = device_init,
    infoChanged = do_preferences,
  },

  can_handle = require("virtual-calendar.can_handle")
}
return virtual_calendar
