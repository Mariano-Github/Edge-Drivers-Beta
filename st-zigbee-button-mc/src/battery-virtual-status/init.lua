--local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery = capabilities.battery
--local utils = require "st.utils"

local device_Info = capabilities["legendabsolute60149.deviceInfo"]

local can_handle = function(opts, driver, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    if device.preferences.profileType == "Batteries" then
      local subdriver = require("battery-virtual-status")
      return true, subdriver
    end 
  end
  return false
end


-- added handler and recalculate batteries Stauts
local function added_handler(driver, device, command)
  print ("<<<< Added device and recalculate batteries status")
  local last_time_batteries_status = device:get_field("last_time_batteries_status")
  if last_time_batteries_status == nil then
    last_time_batteries_status = os.time()- 4000
    device:set_field("last_time_batteries_status", last_time_batteries_status, {persist = false}) 
  end

  local timer_value = 3600
  local batteries_timer = device:get_field("batteries_timer")
  if batteries_timer ~= nil then 
    print("<<<<< Cancel batteries_timer >>>>>")
    driver:cancel_timer(batteries_timer)
    device:set_field("batteries_timer", nil)
  end
  if os.time() - last_time_batteries_status >= 3600 then
    timer_value = 1
  end
  ------  Timer activation
  batteries_timer = device.thread:call_with_delay(timer_value, function(d)

    --if os.time() - last_time_batteries_status >= 3600 then
      device:set_field("batteries_timer", nil)
      timer_value = 3600
      last_time_batteries_status = os.time()
      device:set_field("last_time_batteries_status", last_time_batteries_status, {persist = false})

      local str = "<em style= 'font-weight: bold;'> Zigbee Contact Mc: ".."</em>" .. " Devices Battery Status" .. "<BR>"
      str = str .. "<em style= 'font-weight: bold;'> Last Updated (GMT): ".."</em>" .. os.date("%Y/%m/%d %H:%M:%S", os.time()) .. "<BR>"
      local device_num = 0
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:supports_capability_by_id(capabilities.battery.ID) and
            dev.preferences.childBatteries == true then
              device_num = device_num + 1
              if device.preferences.logDebugPrint == true then
                print("<<<<<<<< get batt status")
                print("<< device_num:", device_num)
                print("<< dev.label:", dev.label)
                print("Batt status:",dev:get_latest_state("main", battery.ID, battery.battery.NAME))
              end
              local batt_status = dev:get_latest_state("main", battery.ID, battery.battery.NAME)
              if batt_status ~= nil then
                if tonumber(batt_status) >= 70 then
                  str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. dev.label ..": ".."</em>" .." <em style= 'color:Green;''>" .. batt_status .. " %".."</em>".. "<BR>"
                elseif tonumber(batt_status) < 70 and tonumber(batt_status) >= 50 then
                  str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. dev.label ..": ".."</em>" .." <em style= 'color:DodgerBlue;''>" .. batt_status .. " %".."</em>".. "<BR>"
                elseif tonumber(batt_status) < 50 and tonumber(batt_status) >= 35 then
                  str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. dev.label ..": ".."</em>" .." <em style= 'color:Orange;''>" .. batt_status .. " %".."</em>".. "<BR>"
                elseif tonumber(batt_status) < 35 then
                  str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. dev.label ..": ".."</em>" .." <em style= 'color:Red;''>" .. batt_status .. " %".."</em>".. "<BR>"
                end
              else
                str = str .. "<em style= 'font-weight: bold;'>".. device_num.. ". ".. dev.label ..": ".."</em>" .. " <em style= 'color:Red;''>".."BATT STATUS PENDING" .."</em>".. "<BR>"
              end
          end 
        end
      end
      str = "<table style='font-size:60%'> <tbody>".. "<tr> <th align=left>" .. "</th> <td>" .. str .. "</td></tr>"

      str = str .. "</tbody></table>"
        
        --device:set_field("set_device_info", str, {persist = true})
        device:emit_event(device_Info.deviceInfo({value = str},{visibility = {displayed = true }}))

    -- set new timer batteries update
    added_handler(driver, device, command)
  end)
  device:set_field("batteries_timer", batteries_timer)
end

--refresh commands
local function do_refresh(driver, device, command)
  print("<<< Refresh batteries status")
  device:set_field("last_time_batteries_status", os.time()- 4000 , {persist = false})

  local batteries_timer = device:get_field("batteries_timer")
  if batteries_timer ~= nil then 
    print("<<<<< Cancel batteries_timer >>>>>")
    driver:cancel_timer(batteries_timer)
    device:set_field("batteries_timer", nil)
  end
  added_handler(driver, device, command)
end


local battery_virtual_status = {
	NAME = "Battery Virtual Stauts",
    capability_handlers = {
      [capabilities.refresh.ID] = {
        [capabilities.refresh.commands.refresh.NAME] = do_refresh,
      }
    },
    lifecycle_handlers = {
      added = added_handler,
      init = do_refresh
    },
	can_handle = can_handle
}

return battery_virtual_status
