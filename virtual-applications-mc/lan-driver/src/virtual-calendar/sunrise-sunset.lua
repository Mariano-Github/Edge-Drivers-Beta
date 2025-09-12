-- Module for calculating sunrise/sunset times for a given location
-- Based on algorithm by United Stated Naval Observatory, Washington
-- Link: http://williams.best.vwh.net/sunrise_sunset_algorithm.htm
-- @author Alexander Yakushev
-- @license CC0 http://creativecommons.org/about/cc0

-- Module sunrise_sunset adapted to Edge driver by Mariano Colmenarejo

local sunrise_sunset = {}
 
 local current_time = nil
 local srs_args
 local rad = math.rad
 local deg = math.deg
 local floor = math.floor
 local frac = function(n) return n - floor(n) end
 local cos = function(d) return math.cos(rad(d)) end
 local acos = function(d) return deg(math.acos(d)) end
 local sin = function(d) return math.sin(rad(d)) end
 local asin = function(d) return deg(math.asin(d)) end
 local tan = function(d) return math.tan(rad(d)) end
 local atan = function(d) return deg(math.atan(d)) end
 
 local function fit_into_range(val, min, max)
    local range = max - min
    local count
    if val < min then
       count = floor((min - val) / range) + 1
       return val + count * range
    elseif val >= max then
       count = floor((val - max) / range) + 1
       return val - count * range
    else
       return val
    end
 end
 
 local function day_of_year(date)
    local n1 = floor(275 * date.month / 9)
    local n2 = floor((date.month + 9) / 12)
    local n3 = (1 + floor((date.year - 4 * floor(date.year / 4) + 2) / 3))
    return n1 - (n2 * n3) + date.day - 30
 end
 
 local function sunturn_time(device, date, rising, latitude, longitude, zenith, local_offset)
    local n = day_of_year(date)
 
    -- Convert the longitude to hour value and calculate an approximate time
    local lng_hour = longitude / 15
 
    local t
    if rising then -- Rising time is desired
       t = n + ((6 - lng_hour) / 24)
       if device.preferences.logDebugPrint == true then
         print(">>>> t sunrise:",t)
       end
    else -- Setting time is desired
       t = n + ((18 - lng_hour) / 24)
       if device.preferences.logDebugPrint == true then
         print(">>>> t sunset:",t)
       end
    end
 
    -- Calculate the Sun's mean anomaly
    local M = (0.9856 * t) - 3.289
 
    -- Calculate the Sun's true longitude
    local L = fit_into_range(M + (1.916 * sin(M)) + (0.020 * sin(2 * M)) + 282.634, 0, 360)
 
    -- Calculate the Sun's right ascension
    local RA = fit_into_range(atan(0.91764 * tan(L)), 0, 360)
 
    -- Right ascension value needs to be in the same quadrant as L
    local Lquadrant  = floor(L / 90) * 90
    local RAquadrant = floor(RA / 90) * 90
    RA = RA + Lquadrant - RAquadrant
 
    -- Right ascension value needs to be converted into hours
    RA = RA / 15
 
    -- Calculate the Sun's declination
    local sinDec = 0.39782 * sin(L)
    local cosDec = cos(asin(sinDec))
 
    -- Calculate the Sun's local hour angle
    local cosH = (cos(zenith) - (sinDec * sin(latitude))) / (cosDec * cos(latitude))

    if device.preferences.logDebugPrint == true then
      print("<<<<<<< rising:", rising, "<<<<<<<<<< cosH", cosH)
    end

   if cosH > 1 or cosH < -1 then
      if rising == true and (cosH < -1 or  cosH > 1) then
         if cosH > 1 then
            return "N/R" -- The sun never rises on this location on the specified date
         else
            return "A/R" -- The sun always rises on this location on the specified date
         end
      elseif  rising == false and (cosH < -1 or  cosH > 1) then
         if cosH < -1 then
            return "N/S" -- The sun never sets on this location on the specified date
         else
            return "A/S" -- The sun always sets on this location on the specified date
         end
      end
   end

    -- Finish calculating H and convert into hours
    local H
    if rising then
       H = 360 - acos(cosH)
    else
       H = acos(cosH)
    end
    H = H / 15
 
    --Calculate local mean time of rising/setting
    local T = H + RA - (0.06571 * t) - 6.622

    if device.preferences.logDebugPrint == true then
      print(">>>>> T",T)
      print(">>>>> lng_hour",lng_hour)
    end

    -- Adjust back to UTC
    local UT = fit_into_range(T - lng_hour, 0, 24)
 
    -- Convert UT value to local time zone of latitude/longitude  
     local LT =  UT + local_offset
     --print(">>>>>> PRE_UT", UT,">>>>>> PRE_LT", LT)
      if LT < 0 then
         LT = LT + 24
      elseif LT >= 24 then
         LT = LT - 24
      end
   
      if device.preferences.logDebugPrint == true then
         print(">>>>>> UT", UT,">>>>>> LT", LT)
         print(">>>>>> Day:",date.day,">>>>>> Mes:",date.month,">>>>>> Año:",date.year)
         print(">>>>> Return",os.time({ day = date.day, month = date.month, year = date.year, hour = floor(LT), min = floor(frac(LT) * 60)}))
      end
    
    return os.time({ day = date.day, month = date.month, year = date.year, hour = floor(LT), min = floor(frac(LT) * 60)})

 end
 
 function sunrise_sunset.get(device, lat, lon, offset)
   local args = {}
   local date = os.date("*t")
   --local lat = lat
   --local lon = lon
   --local offset = offset
   local zenith = 90.83

   local rise_time = sunturn_time(device, date, true, lat, lon, zenith, offset)
   local set_time = sunturn_time(device, date, false, lat, lon, zenith, offset)

   if device.preferences.logDebugPrint == true then
      print("<<<<<rise_time_previous-Adjust",rise_time,"set_time",set_time)
   end
   local length = 0
   if rise_time == "N/R" or (rise_time == "N/R" and set_time == "A/S") then
      length = 0
      rise_time = os.time()
      set_time = os.time()
   --elseif  set_time == "N/S" or (rise_time == "A/R" and set_time == "N/S") or (set_time < rise_time) then
   elseif  set_time == "N/S" or (rise_time == "A/R" and set_time == "N/S") then
      length = 24
      rise_time = os.time()
      set_time = os.time() + 24 * 3600
   elseif (set_time < rise_time) then
      length = 24 + ((set_time - rise_time) / 3600)
      set_time = set_time + 24 * 3600
   else   
      length = (set_time - rise_time) / 3600
   end

   if device.preferences.logDebugPrint == true then
      print("<<<<<rise_time",rise_time,"set_time",set_time)
      print(" <<<",os.date("Sunrise: %m/%d/%Y %H:%M:%S",rise_time), os.date("Sunset: %m/%d/%Y %H:%M:%S",set_time), "Day Duration: ", math.floor(length), "Hrs",frac(length)* 60,"Min >>>")
   end
   return rise_time, set_time, math.floor(length), math.floor(frac(length) * 60)
 end

 return sunrise_sunset