-- Module for calculating sun position Elevation and Azimuth angles for a given location
-- Based on function from internet shared by Edi Budimilic
-- Link: https://stackoverflow.com/questions/35467309/position-of-the-sun-azimuth-in-lua
-- @Modified by M. Colmenarjo to works in all locations and correct error for azimuth angle in East longitude and others


local sun_position = {}

-- solar altitude, azimuth (degrees)
function sun_position.sunposition(device, latitude, longitude, time)
    time = time or os.time()
    if type(time) == 'table' then time = os.time(time) end
  
    local date = os.date('*t', time)
    local utcdate = os.date('*t', time)
    local latrad = math.rad(latitude)
    local fd = (utcdate.hour + utcdate.min / 60 + utcdate.sec / 3600) / 24
    local g = (2 * math.pi / 365.25) * (utcdate.yday + fd)
    local d = math.rad(0.396372 - 22.91327 * math.cos(g) + 4.02543 * math.sin(g) - 0.387205 * math.cos(2 * g)
      + 0.051967 * math.sin(2 * g) - 0.154527 * math.cos(3 * g) + 0.084798 * math.sin(3 * g))
    local t = math.rad(0.004297 + 0.107029 * math.cos(g) - 1.837877 * math.sin(g)
      - 0.837378 * math.cos(2 * g) - 2.340475 * math.sin(2 * g))
    local sha = 2 * math.pi * (fd - 0.5) + t + math.rad(longitude)
  
    local sza = math.acos(math.sin(latrad) * math.sin(d) + math.cos(latrad) * math.cos(d) * math.cos(sha))
    local saa = math.acos((math.sin(d) - math.sin(latrad) * math.cos(sza)) / (math.cos(latrad) * math.sin(sza)))

    if device.preferences.logDebugPrint == true then
      print("<<<<<<<<<<<< utcdate.hour",utcdate.hour,"utcdate.min",utcdate.min)
      print("<<<<<< sza",sza,"<<<<<< saa",saa)
      print("<<<<< longitude",longitude,"Altitude",math.deg(sza),"Azimuth",math.deg(saa))
    end

    return 90 - math.deg(sza), math.deg(saa)
 end

  -- adjust azimuth according to lat and long 
  function sun_position.getSunPos(device, lat, long, time)

    -- calculate UTC time altitude and azimuth
    local altitude, azimuth = sun_position.sunposition(device,lat, long, time)

    -- Check previous 1 minute values to detect azimuth direction change 0º and 180º
    time = time - 60 
    local previuos_altitude, previuos_azimuth = sun_position.sunposition(device, lat, long, time)

    if device.preferences.logDebugPrint == true then
      print("previuos_azimuth",previuos_azimuth,"<<<< azimuth",azimuth)
      if previuos_azimuth < azimuth then
        print("<<<<<<<<<<<<< TREND:", "UP")
      else
        print("<<<<<<<<<<<<< TREND:", "DOWN")
      end
    end
    
    if previuos_azimuth < azimuth then -- calcualted azimuth trend UP >>>>>>>>>>>>>>>>>>>
      if long < 0 then
        if lat > 0 then
          return altitude, azimuth
        else
          return altitude, 360 - azimuth
        end
      else ------------------- long > 0
        if lat > 0 then
          return altitude, azimuth
        else
          return altitude, 360 - azimuth
        end
      end
    else -- calcualted azimuth trend DOWN >>>>>>>>>>>>>>>>>>>
      if long < 0 then
        if lat > 0 then
          return altitude,360 - azimuth
        else
          return altitude, azimuth
        end
      else ------------------- long > 0
        if lat > 0 then
         return altitude, 360 - azimuth
        else
          return altitude, azimuth
        end
      end
    end
  end

 return sun_position