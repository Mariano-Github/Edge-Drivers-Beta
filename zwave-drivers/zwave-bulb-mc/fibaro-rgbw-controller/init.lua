-- Copyright 2021 SmartThings
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
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })
--- @type st.zwave.CommandClass.SwitchColor
local SwitchColor = (require "st.zwave.CommandClass.SwitchColor")({ version = 1 })
--- @type st.zwave.CommandClass.SwitchMultilevel
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({ version = 1 })
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({ version = 2 })
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 }) --manual verison =1
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({version=1,strict=true})
local utils = require "st.utils"

local ColorControlDefaults = require "st.zwave.defaults.colorControl"
local SwitchLevelDefaults = require "st.zwave.defaults.switchLevel"

local child_devices = require "child-devices"

local CAP_CACHE_KEY = "st.capabilities." .. capabilities.colorControl.ID
local LAST_COLOR_SWITCH_CMD_FIELD = "lastColorSwitchCmd"
local FAKE_RGB_ENDPOINT = 10
local WHITE_ENDPOINT = 9
local R_ENDPOINT = 6
local G_ENDPOINT = 7
local B_ENDPOINT = 8
local rgbwl={}
local red = {}
local green =  {}
local blue = {}
local white = {}

local programmed_Sequence = capabilities["legendabsolute60149.programmedSequence"]

local FIBARO_MFR_ID = 0x010F
local FIBARO_RGBW_CONTROLLER_PROD_TYPE = 0x0900
--local FIBARO_RGBW_CONTROLLER_PROD_ID_US = 0x2000
--local FIBARO_RGBW_CONTROLLER_PROD_ID_EU = 0x1000

local function is_fibaro_rgbw_controller(opts, driver, device, ...)
  if device:id_match(FIBARO_MFR_ID,
    FIBARO_RGBW_CONTROLLER_PROD_TYPE) then
    local subdriver = require("fibaro-rgbw-controller")
    return true, subdriver
  end
  return false
end

--- set DELAY dimmin fibaro rgbw
local function set_delay(driver, device)
  local delay = constants.DEFAULT_POST_DIMMING_DELAY
  if device.preferences.outputsStateMode == "0" then
    delay = delay + (device.preferences.stepValue * device.preferences.timeBetweenSteps / 1000)
  else
    if device.preferences.timeChangingStartEnd >= 0 and device.preferences.timeChangingStartEnd <= 63 then
      delay = delay + (device.preferences.timeChangingStartEnd * 20 / 1000)
    elseif device.preferences.timeChangingStartEnd > 63 and device.preferences.timeChangingStartEnd <= 127 then
      delay =delay + (device.preferences.timeChangingStartEnd - 64)
    elseif device.preferences.timeChangingStartEnd > 127 and device.preferences.timeChangingStartEnd <= 191 then
      delay = delay + (device.preferences.timeChangingStartEnd - 128 * 10)
    elseif device.preferences.timeChangingStartEnd > 193 and device.preferences.timeChangingStartEnd <= 255 then
      delay = delay + (device.preferences.timeChangingStartEnd - 192 * 60)
    end
  end
  print("<<<<<< calculated_delay", delay )
  device:set_field("Calculated_Delay", delay)
  if delay > 8 then delay = 8 end
  device:set_field("Minimum_Delay", delay)
end

-- emit event for child devices
local function child_emit_event(driver, device, command, value)
  print("<<<<<< child_emit_event >>>>>>")
  --print("<<<< command.component",command.component)
  --print("<<<< command.src_channel",command.src_channel)
  local child_device = device:get_child_by_parent_assigned_key(command.component)
  if child_device ~= nil then
    if value > 0 then
      child_device:emit_event(capabilities.switch.switch.on())
      child_device:emit_event(capabilities.switchLevel.level(math.floor(value / 254 * 100 + 0.5)))
    else
      child_device:emit_event(capabilities.switch.switch.off())
      child_device:emit_event(capabilities.switchLevel.level(0))
    end
  end
end

--- rgbw_level handler
local function rgbwl_handler(driver, device, rgbwl)
  print("<<<< rgbwl_handler-0")
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    --initialize variables to emit components state
    red[device.id], green[device.id], blue[device.id], white[device.id] = -1, -1, -1, -1

    print("<<<<< rgbwl_handler >>>>>>>")
    local set = SwitchColor:Set({
      color_components = {
        { color_component_id=SwitchColor.color_component_id.RED, value= rgbwl[device.id].r },
        { color_component_id=SwitchColor.color_component_id.GREEN, value= rgbwl[device.id].g },
        { color_component_id=SwitchColor.color_component_id.BLUE, value= rgbwl[device.id].b },
        { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value= rgbwl[device.id].w},
      }
    })
    if device.preferences.channelOperation == "Normal" then
      set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.RED, value= rgbwl[device.id].r },
          { color_component_id=SwitchColor.color_component_id.GREEN, value= rgbwl[device.id].g },
          { color_component_id=SwitchColor.color_component_id.BLUE, value= rgbwl[device.id].b },
          { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value= 0},
        }
      }) 
    end
    device:send(set)

    --set last level
    set = SwitchMultilevel:Set({value=rgbwl[device.id].l})
    device:send(set)

    local query_level = function()
      --device:send_to_component(SwitchMultilevel:Get({}), "main")
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
      device:send(SwitchMultilevel:Get({}))
    end
    device.thread:call_with_delay(device:get_field("Minimum_Delay"), query_level)
  end
end

-- This handler is copied from defaults with scraped of sets for both WHITE channels
local function set_color(driver, device, command)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<<<< set_color >>>>>>>")
    --initialize variables to emit components state
    red[device.id], green[device.id], blue[device.id], white[device.id] = -1, -1, -1, -1

    local r, g, b = utils.hsl_to_rgb(command.args.color.hue, command.args.color.saturation, command.args.color.lightness)
    --print("<<<<<<<< command.args.color.lightness",command.args.color.lightness)
    if r > 0 or g > 0 or b > 0 then
      device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 255)
      device:set_field(CAP_CACHE_KEY, command)
      rgbwl[device.id].r= r
      rgbwl[device.id].g = g
      rgbwl[device.id].b = b
      if device.preferences.channelOperation == "Normal" then 
        rgbwl[device.id].w = 0
      end
    end

    local set = SwitchColor:Set({
      color_components = {
        { color_component_id=SwitchColor.color_component_id.RED, value=r },
        { color_component_id=SwitchColor.color_component_id.GREEN, value=g },
        { color_component_id=SwitchColor.color_component_id.BLUE, value=b },
        { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value=0 },
      },
      --duration=duration
    })
    if device.preferences.channelOperation == "Independent" then
      set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.RED, value=r },
          { color_component_id=SwitchColor.color_component_id.GREEN, value=g },
          { color_component_id=SwitchColor.color_component_id.BLUE, value=b },
        },
      })
    end
    device:send(set)

     --set last level
     set = SwitchMultilevel:Set({value=rgbwl[device.id].l})
     device:send(set)

    local query_color = function()
      -- Use a single RGB color key to trigger our callback to emit a color
      -- control capability update.
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      --device:send_to_component(SwitchMultilevel:Get({}), "main")
      device:send(SwitchMultilevel:Get({}))
    end
    device.thread:call_with_delay(device:get_field("Minimum_Delay"), query_color)

    local red_val= math.floor(r / 254 * 100 + 0.5)
    local green_val= math.floor(g / 254 * 100 + 0.5)
    local blue_val= math.floor(b / 254 * 100 + 0.5)
    device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switchLevel.level(red_val))
    device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switchLevel.level(green_val))
    device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switchLevel.level(blue_val))
  end
end

------- set_hue
local function set_hue(driver, device, command)
  print("<<<< set_hue Handler >>>>>")
  local setColorCommand = device:get_field(CAP_CACHE_KEY)
  if setColorCommand ~= nil and (setColorCommand.args.color.saturation > 0 or setColorCommand.args.color.hue > 0) then
    print("<<<<< SetHue",command.args.hue)
    print("<<<<< Last_Saturation",setColorCommand.args.color.saturation)
    setColorCommand.args.color.hue = command.args.hue
      set_color(driver, device, setColorCommand)
  else
    local mockCommand = {args = {color = {hue = command.args.hue, saturation = 100}}}
    set_color(driver, device, mockCommand)
  end
end

------- set_saturation
local function set_saturation(driver, device, command)
  print("<<<< set_sat Handler >>>>>")
  local setColorCommand = device:get_field(CAP_CACHE_KEY)
  if setColorCommand ~= nil and (setColorCommand.args.color.saturation > 0 or setColorCommand.args.color.hue > 0) then
    print("<<<<< SetSaturation",command.args.saturation)
    print("<<<<< Last_Hue",setColorCommand.args.color.hue)
    setColorCommand.args.color.saturation = command.args.saturation
      set_color(driver, device, setColorCommand)
  else
    local mockCommand = {args = {color = {hue = 100, saturation = command.args.saturation}}}
    set_color(driver, device, mockCommand)
  end
end

-----switch_color_report
local function switch_color_report(driver, device, command)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
      print("<<<<< switch_color_report >>>>>>>")
      local value = command.args.value
      --if command.args.color_component_id ~= SwitchColor.color_component_id.WARM_WHITE then
        --command.src_channel = FAKE_RGB_ENDPOINT --- main component
        --ColorControlDefaults.zwave_handlers[cc.SWITCH_COLOR][SwitchColor.REPORT](driver, device, command)
      --end

      if command.args.color_component_id == SwitchColor.color_component_id.WARM_WHITE then
        value = command.args.value
        --print("<<<<< white value:",command.args.value)
        if value > 0 then
          white[device.id] = 1
        else 
          white[device.id] = 0
        end
        device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switchLevel.level(math.floor(value / 254 * 100 + 0.5)))
        if device:get_field("LastWhite") > 0 then
          rgbwl[device.id].w = command.args.value
        end

        -- emit event for child devices
        command.component = "white"
        child_emit_event(driver, device, command, value)

      elseif command.args.color_component_id == SwitchColor.color_component_id.RED then
          --Emit hue and saturation        
          --ColorControlDefaults.zwave_handlers[cc.SWITCH_COLOR][SwitchColor.REPORT](driver, device, command)

          device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switchLevel.level(math.floor(command.args.value / 254 * 100 + 0.5)))
          if device:get_field(LAST_COLOR_SWITCH_CMD_FIELD) > 0 then
            rgbwl[device.id].r = command.args.value
          end
          if value == 0 then
            red[device.id] = 0
          else
            red[device.id] = 1
          end
          -- emit event for child devices
          command.component = "red"
          child_emit_event(driver, device, command, value)

      elseif command.args.color_component_id == SwitchColor.color_component_id.GREEN then
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switchLevel.level(math.floor(command.args.value / 254 * 100 + 0.5)))
        if device:get_field(LAST_COLOR_SWITCH_CMD_FIELD) > 0 then
          rgbwl[device.id].g = command.args.value
        end
        if value == 0 then
          green[device.id] = 0
        else
          green[device.id] = 1
        end
        -- emit event for child devices
        command.component = "green"
        child_emit_event(driver, device, command, value)

      elseif command.args.color_component_id == SwitchColor.color_component_id.BLUE then
        device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switchLevel.level(math.floor(command.args.value / 254 * 100 + 0.5)))
        if device:get_field(LAST_COLOR_SWITCH_CMD_FIELD) > 0 then
          rgbwl[device.id].b = command.args.value
        end
        if value == 0 then
          blue[device.id] = 0
        else
          blue[device.id] = 1
        end
        -- emit event for child devices
        command.component = "blue"
        child_emit_event(driver, device, command, value)
      end

      print("<<<< red, green, blue, white", red[device.id],green[device.id],blue[device.id],white[device.id])
      -- emit switch main and white events
      if red[device.id] > -1 and green[device.id] > -1 and blue[device.id] > -1 and white[device.id] > -1 then
        if white[device.id] == 0 then
          device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.off())
        else
          device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.on())
          device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())
        end
        if red[device.id] == 0 then
          device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switch.switch.off())
        else
          device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switch.switch.on())
          device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())
        end
        if green[device.id] == 0 then
          device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switch.switch.off())
        else
          device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switch.switch.on())
          device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())
        end
        if blue[device.id] == 0 then
          device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switch.switch.off())
        else
          device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switch.switch.on())
          device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())
        end

        if red[device.id] == 0 and green[device.id] == 0 and blue[device.id] == 0 and white[device.id] == 0 then
            device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.off())
            device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.off())
        elseif red[device.id] == 0 or green[device.id] == 0 or blue[device.id] == 0 or white[device.id] == 1 then
          device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())
        end

        if red[device.id] == 1 or green[device.id] == 1 or blue[device.id] == 1  then
          local hue, sat = utils.rgb_to_hsl(rgbwl[device.id].r, rgbwl[device.id].g, rgbwl[device.id].b)
          device:emit_event_for_endpoint("main", capabilities.colorControl.hue(hue))
          device:emit_event_for_endpoint("main", capabilities.colorControl.saturation(sat))
          --save last hue and sat
            --local sat = device:get_latest_state("main",capabilities.colorControl.ID,capabilities.colorControl.saturation.NAME)
            --local hue = device:get_latest_state("main",capabilities.colorControl.ID,capabilities.colorControl.hue.NAME)
          print("<<<<< hue, sat",hue, sat)
          local mockCommand = {args = {color = {hue = hue, saturation = sat}}}
          device:set_field(CAP_CACHE_KEY, mockCommand)

          local query_refresh = function()
            device:refresh()
          end
          --device.thread:call_with_delay(4, query_refresh)
        end
        red[device.id], green[device.id], blue[device.id], white[device.id] = -1, -1, -1, -1
      end
  end
end

--- switch_multilevel_report
local function switch_multilevel_report(self, device, command)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<<<< switch_multilevel_report >>>>>>>")
    local endpoint = command.src_channel
    -- ignore multilevel reports from endpoints [1, 2, 3, 4] which mirror SwitchColor values
    -- and in addition cause wrong SwitchLevel events
    --if  (endpoint < 1 and endpoint > 4) then
    local value = command.args.value
    if  (endpoint == 0) then
      if command.args.value == SwitchMultilevel.value.OFF_DISABLE or command.args.value == 0 then
        device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.off())
        device:emit_component_event(device.profile.components["main"], capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switchLevel.level(0))
      else
        if device:get_field(LAST_COLOR_SWITCH_CMD_FIELD) > 0 then
          rgbwl[device.id].l = value
        end
        SwitchLevelDefaults.zwave_handlers[cc.SWITCH_MULTILEVEL][SwitchMultilevel.REPORT](self, device, command)
      end
    --end
    else
      --if command.args.value == SwitchMultilevel.value.OFF_DISABLE then
      if device:get_field("Calculated_Delay") > device:get_field("Minimum_Delay") then
        local query_level = function()
          --device:send_to_component(get, command.component)
          --device:send(get)
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
        end
        device.thread:call_with_delay(device:get_field("Minimum_Delay"), query_level)
      end
    end
  end
end

-- set_switch_level_handler
local function set_switch_level_handler(driver, device, command)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<<< set_switch_level_handler >>>>")
    --initialize variables to emit components state
    red[device.id], green[device.id], blue[device.id], white[device.id] = -1, -1, -1, -1

    local level = utils.round(command.args.level)
    level = utils.clamp_value(level, 0, 99)
    local set
    local get
    if command.component == "main" then
      local delay = device:get_field("Minimum_Delay") -- delay in seconds
      if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        local last_level = rgbwl[device.id].l
        print("<<<<< last_level",last_level)
        local inc_level = level - last_level
        rgbwl[device.id].l = level
        rgbwl[device.id].r = rgbwl[device.id].r  + math.floor(inc_level * 254 / 100 + 0.5)
        rgbwl[device.id].g = rgbwl[device.id].g  + math.floor(inc_level * 254 / 100 + 0.5)
        rgbwl[device.id].b = rgbwl[device.id].b  + math.floor(inc_level * 254 / 100 + 0.5)
        rgbwl[device.id].w = rgbwl[device.id].w  + math.floor(inc_level * 254 / 100 + 0.5)
        if rgbwl[device.id].r > 255 then rgbwl[device.id].r = 255 end
        if rgbwl[device.id].r <= 0 then rgbwl[device.id].r = 1 end
        if rgbwl[device.id].g > 255 then rgbwl[device.id].g = 255 end
        if rgbwl[device.id].g <= 0 then rgbwl[device.id].g = 1 end
        if rgbwl[device.id].b > 255 then rgbwl[device.id].b = 255 end
        if rgbwl[device.id].b <= 0 then rgbwl[device.id].b = 1 end
        if rgbwl[device.id].w > 255 then rgbwl[device.id].w = 255 end
        if rgbwl[device.id].w <= 0 then rgbwl[device.id].w = 1 end
        if rgbwl[device.id].r > 0 and rgbwl[device.id].g > 0 and rgbwl[device.id].b > 0 then
          device:set_field("rgbwl".. device.id,rgbwl[device.id], {persist = true})
        end
        rgbwl_handler(driver, device,rgbwl)
        return
      end
      if device:is_cc_supported(cc.SWITCH_MULTILEVEL) then
        get = SwitchMultilevel:Get({})
        set = SwitchMultilevel:Set({ value=level})
      end
      device:send_to_component(set, command.component)
      --device:send(set)
      local query_level = function()
        device:send_to_component(get, command.component)
        --device:send(get)
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
      end
      device.thread:call_with_delay(delay, query_level)
      if level > 0 then
        rgbwl[device.id].l = level
      end
    else
      local r = math.floor(device:get_latest_state("red", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) * 254 / 100 + 0.5)
      local g = math.floor(device:get_latest_state("green", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) * 254 / 100 + 0.5)
      local b = math.floor(device:get_latest_state("blue", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) * 254 / 100 + 0.5)
      local w = math.floor(device:get_latest_state("white", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) * 254 / 100 + 0.5)
      --print("<<<<<<<<<< level, r,g,b,w",level, r,g,b,w)
      if command.component == "red" then
        device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switchLevel.level(level))
        r = math.floor(level * 254 / 100 + 0.5)
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.RED, value= r },
          }
        })
        device:send(set)
      elseif command.component == "green" then
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switchLevel.level(level))
        g = math.floor(level * 254 / 100 + 0.5)
        set = SwitchColor:Set({
          color_components = {
            {color_component_id=SwitchColor.color_component_id.GREEN, value= g },
          }
        })
        device:send(set)
      elseif command.component == "blue" then
        device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switchLevel.level(level))
        b = math.floor(level * 254 / 100 + 0.5)
        set = SwitchColor:Set({
          color_components = {
            {color_component_id=SwitchColor.color_component_id.BLUE, value= b },
          }
        })
        device:send(set)
      elseif command.component == "white" then
          device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switchLevel.level(level))
          w = math.floor(level * 254 / 100 + 0.5)
          print("<<<<<< w ",w)
          device:set_field("LastWhite", w, {persist = true})
          set = SwitchColor:Set({
            color_components = {
              { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = w },
            }
          })
          if device.preferences.channelOperation == "Normal" then
            set = SwitchColor:Set({
              color_components = {
                { color_component_id=SwitchColor.color_component_id.RED, value=0 },
                { color_component_id=SwitchColor.color_component_id.GREEN, value=0 },
                { color_component_id=SwitchColor.color_component_id.BLUE, value=0 },
                { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = w },
              }
            })
          end
          device:send(set)
          if w > 0 then
            rgbwl[device.id].w = w
            device:set_field("LastWhite", 255, {persist = true})
          end
      end
      if device.preferences.channelOperation == "Normal" and command.component ~= "white" and command.component ~= "main"then
          set = SwitchColor:Set({
            color_components = {
              { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
            }
          })
        device:send(set)
        device:set_field("LastWhite", 0, {persist = true})
      end

      --print("<<<<<<<<<< level, r,g,b",level, r,g,b)
      if r ~= nil and g ~= nil and b ~= nil and (r > 0 or b > 0 or g > 0) then
        local h, s, l= utils.rgb_to_hsl(r, g, b)
        --print("<<<<<<< h,s,l",h, s, l)
        --local mockCommand = {args = {color = {hue = h, saturation = s, lightness = l}}}
        local mockCommand = {args = {color = {hue = h, saturation = s}}}
        if r > 0 or g > 0 or b > 0 then
          device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 255)
          device:set_field(CAP_CACHE_KEY, mockCommand)
          rgbwl[device.id].r = r
          rgbwl[device.id].g = g
          rgbwl[device.id].b = b
        end
        if r == 0 and g == 0 and b == 0 then
          device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)
        end

      end
        local query = function()
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
          device:send(SwitchMultilevel:Get({}))
        end
        device.thread:call_with_delay(device:get_field("Minimum_Delay"), query)
    end
  else ------ Is child device --------------
    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    local level = utils.round(command.args.level)
    level = utils.clamp_value(level, 0, 99)
    local set
    if component == "white" then
      if level > 0 then
        device:emit_event(capabilities.switch.switch.on())
        parent_device:set_field("LastWhite", 255, {persist = true})
        device:emit_event(capabilities.switchLevel.level(level))
        local w = math.floor(level * 254 / 100 + 0.5)
        rgbwl[device.parent_device_id].w = w
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = w },
          }
        })
        if parent_device.preferences.channelOperation == "Normal" then
          set = SwitchColor:Set({
            color_components = {
              { color_component_id=SwitchColor.color_component_id.RED, value=0 },
              { color_component_id=SwitchColor.color_component_id.GREEN, value=0 },
              { color_component_id=SwitchColor.color_component_id.BLUE, value=0 },
              { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = w },
            }
          })
        end
      else
        --device:emit_event(capabilities.switch.switch.off())
        parent_device:set_field("LastWhite", 0, {persist = true})
        device:emit_event(capabilities.switchLevel.level(0))
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
          }
        })
      end
    elseif component == "red" then
      if level > 0 then
        device:emit_event(capabilities.switch.switch.on())
        parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 255)
        device:emit_event(capabilities.switchLevel.level(level))
        local r = math.floor(level * 254 / 100 + 0.5)
        rgbwl[device.parent_device_id].r = r
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.RED, value = r },
          }
        })
      else
        --device:emit_event(capabilities.switch.switch.off())
        parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)
        device:emit_event(capabilities.switchLevel.level(0))
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.RED, value = 0 },
          }
        })
      end
    elseif component == "green" then
      if level > 0 then
        device:emit_event(capabilities.switch.switch.on())
        parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 255)
        device:emit_event(capabilities.switchLevel.level(level))
        local g = math.floor(level * 254 / 100 + 0.5)
        rgbwl[device.parent_device_id].g = g
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.GREEN, value = g },
          }
        })
      else
        --device:emit_event(capabilities.switch.switch.off())
        parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)
        device:emit_event(capabilities.switchLevel.level(0))
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.GREEN, value = 0 },
          }
        })
      end
    elseif component == "blue" then
      if level > 0 then
        device:emit_event(capabilities.switch.switch.on())
        parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 255)
        device:emit_event(capabilities.switchLevel.level(level))
        local b = math.floor(level * 254 / 100 + 0.5)
        rgbwl[device.parent_device_id].b = b
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.BLUE, value = b },
          }
        })
      else
        --device:emit_event(capabilities.switch.switch.off())
        parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)
        device:emit_event(capabilities.switchLevel.level(0))
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.BLUE, value = 0 },
          }
        })
      end
    end
    parent_device:send(set)
    if parent_device.preferences.channelOperation == "Normal" and component ~= "white" then
      set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
        }
      })
      parent_device:send(set)
      parent_device:set_field("LastWhite", 0, {persist = true})
    end

    local query = function()
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
      parent_device:send(SwitchMultilevel:Get({}))
    end
    device.thread:call_with_delay(parent_device:get_field("Minimum_Delay"), query)
  end
end

------ set switch on-off
local function set_switch(driver, device, command, value)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<<< set_switch >>>>")
    print("<<<< command.component",command.component)
    print("<<<< value",value)
    --initialize variables to emit components state
    red[device.id], green[device.id], blue[device.id], white[device.id] = -1, -1, -1, -1

    local set
    if command.component == "white" then
      set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = value },
        }
      })
      if value > 0 then
        if device.preferences.channelOperation == "Normal" then
          set = SwitchColor:Set({
            color_components = {
              { color_component_id=SwitchColor.color_component_id.RED, value=0 },
              { color_component_id=SwitchColor.color_component_id.GREEN, value=0 },
              { color_component_id=SwitchColor.color_component_id.BLUE, value=0 },
              { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = value },
            }
          })
        end
        rgbwl[device.id].w = value
        print("<<<WHITE_ENDPOINT",WHITE_ENDPOINT)
        device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.on())
      end
      child_emit_event(driver, device, command, value)

    elseif command.component == "red" then
      set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.RED, value = value },
        }
      })
      if value > 0 then
        if device.preferences.channelOperation == "Normal" then
          set = SwitchColor:Set({
            color_components = {
              { color_component_id=SwitchColor.color_component_id.RED, value= value },
              { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
            }
          })
        end
        rgbwl[device.id].r = value
        device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switch.switch.on())
      end
      child_emit_event(driver, device, command, value)

    elseif command.component == "green" then
      set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.GREEN, value = value },
        }
      })
      if value > 0 then
        if device.preferences.channelOperation == "Normal" then
          set = SwitchColor:Set({
            color_components = {
              { color_component_id=SwitchColor.color_component_id.GREEN, value= value },
              { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
            }
          })
        end
        rgbwl[device.id].g = value
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switch.switch.on())
      end
      child_emit_event(driver, device, command, value)

    elseif command.component == "blue" then
      set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.BLUE, value = value },
        }
      })
      if value > 0 then
        if device.preferences.channelOperation == "Normal" then
          set = SwitchColor:Set({
            color_components = {
              { color_component_id=SwitchColor.color_component_id.BLUE, value= value },
              { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
            }
          })
        end
        rgbwl[device.id].b = value
        device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switch.switch.on())
      end
      child_emit_event(driver, device, command, value)
    end
    if command.component ~= "main" then
      device:send(set)
      local query_white = function()
        device:send(SwitchMultilevel:Get({}))
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
        device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      end
      device.thread:call_with_delay(device:get_field("Minimum_Delay"), query_white)
    end

    if command.component == "main" then
      device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, value)
      if value == 255 then
        if device:get_field("rgbwl".. device.id) == nil or (rgbwl[device.id].r == 0 and  rgbwl[device.id].g == 0 and rgbwl[device.id].b == 0) or rgbwl[device.id].l ==0 then
          local setColorCommand = device:get_field(CAP_CACHE_KEY)
          if setColorCommand ~= nil and (setColorCommand.args.color.saturation > 0 or setColorCommand.args.color.hue > 0) then
            set_color(driver, device, setColorCommand)
          else
            local mockCommand = {args = {color = {hue = 0, saturation = 50}}}
            set_color(driver, device, mockCommand)
          end
        else
            rgbwl_handler(driver, device,rgbwl)
        end
        device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())

      else
        if rgbwl[device.id].r > 0 or rgbwl[device.id].g > 0 or rgbwl[device.id].b > 0 then
          device:set_field("rgbwl".. device.id,rgbwl[device.id], {persist = true})
        end
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.RED, value=0 },
            { color_component_id=SwitchColor.color_component_id.GREEN, value=0 },
            { color_component_id=SwitchColor.color_component_id.BLUE, value=0 },
            { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value=0},
          }
        })
        device:send(set)
        set = SwitchBinary:Set({
          target_value = SwitchBinary.value.OFF_DISABLE,
        })
        device:send(set)
        --device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.off())
        local query_color = function()
          device:send(SwitchMultilevel:Get({}))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
          device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
        end
        device.thread:call_with_delay(device:get_field("Minimum_Delay"), query_color)
      end
    end
  end
end

--- set_switch_on
local function set_switch_on(driver, device, command)
  print("<<< set_switch_on >>>")
  print("<<< device.id",device.id)
  print("<<< device.network_type",device.network_type)
  --print("<<< rgbwl[device.id].w",rgbwl[device.id].w)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local value = 255
    device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 255)
    if command.component == "white" then
      device:set_field("LastWhite", 255, {persist = true})
      value = rgbwl[device.id].w
      if value == nil or value == 0 then  value = 255 end
    elseif command.component == "red" then
      value = rgbwl[device.id].r
      if value == nil or value == 0 then  value = 255 end
    elseif command.component == "green" then
      value = rgbwl[device.id].g
      if value == nil or value == 0 then  value = 255 end
    elseif command.component == "blue" then
      value = rgbwl[device.id].b
      if value == nil or value == 0 then  value = 255 end
    end
    set_switch(driver, device, command, value)
  else
    local value = 255
    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    if component == "white" then
      device:emit_event(capabilities.switch.switch.on())
      parent_device:set_field("LastWhite", 255, {persist = true})
      value = rgbwl[device.parent_device_id].w
      if value == nil or value == 0 then  
        value = 255
        rgbwl[device.parent_device_id].w = value
      end
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = value },
        }
      })
      if parent_device.preferences.channelOperation == "Normal" then
        set = SwitchColor:Set({
          color_components = {
            { color_component_id=SwitchColor.color_component_id.RED, value=0 },
            { color_component_id=SwitchColor.color_component_id.GREEN, value=0 },
            { color_component_id=SwitchColor.color_component_id.BLUE, value=0 },
            { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = value },
          }
        })
      end
      parent_device:send(set)
      parent_device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.on())
    elseif component == "red" then
      device:emit_event(capabilities.switch.switch.on())
      value = rgbwl[device.parent_device_id].r
      if value == nil or value == 0 then  
        value = 255
        rgbwl[device.parent_device_id].r = value
      end
      device:emit_event(capabilities.switchLevel.level(math.floor(value /255*100)))
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.RED, value = value },
        }
      })
      parent_device:send(set)
      parent_device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switch.switch.on())
    elseif component == "green" then
      device:emit_event(capabilities.switch.switch.on())
      value = rgbwl[device.parent_device_id].g
      if value == nil or value == 0 then  
        value = 255
        rgbwl[device.parent_device_id].g = value
      end
      device:emit_event(capabilities.switchLevel.level(math.floor(value /255*100)))
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.GREEN, value = value },
        }
      })
      parent_device:send(set)
      parent_device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switch.switch.on())
    elseif component == "blue" then
      device:emit_event(capabilities.switch.switch.on())
      value = rgbwl[device.parent_device_id].b
      if value == nil or value == 0 then
        value = 255
        rgbwl[device.parent_device_id].b = value
      end
      device:emit_event(capabilities.switchLevel.level(math.floor(value /255*100)))
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.BLUE, value = value },
        }
      })
      parent_device:send(set)
      parent_device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switch.switch.on())
    end
    parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 255)
    parent_device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())
    if parent_device.preferences.channelOperation == "Normal" and component ~= "white" then
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
        }
      })
      parent_device:send(set)
    end

    local query = function()
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
      parent_device:send(SwitchMultilevel:Get({}))
    end
    device.thread:call_with_delay(parent_device:get_field("Minimum_Delay"), query)
  end
end

---- set_switch_off
local function set_switch_off(driver, device, command)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    -- final refresh to turn off
    if device:get_field("Calculated_Delay") > device:get_field("Minimum_Delay") then
      print("<<<<< set final refresh >>>>>")
      local query_refresh = function()
        ---- Timers Cancel ------
        for timer in pairs(device.thread.timers) do
          print("<<<<< Cancelando timer >>>>>")
          device.thread:cancel_timer(timer)
        end
        device:refresh()
      end
      device.thread:call_with_delay(device:get_field("Calculated_Delay") + 5, query_refresh)
    end

    device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)
    if command.component == "white" then
      device:set_field("LastWhite", 0, {persist = true})
      if rgbwl[device.id].w == nil or rgbwl[device.id].w == 0 then
        rgbwl[device.id].w = 255
      end
    elseif command.component == "red" then
      if rgbwl[device.id].r == nil or rgbwl[device.id].r == 0 then
        rgbwl[device.id].r = 255
      end
    elseif command.component == "green" then
      if rgbwl[device.id].g == nil or rgbwl[device.id].g == 0 then
        rgbwl[device.id].g = 255
      end
    elseif command.component == "blue" then
      if rgbwl[device.id].b == nil or rgbwl[device.id].b == 0 then
        rgbwl[device.id].b = 255
      end
    end
    set_switch(driver, device, command, 0)
  else
    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    if component == "white" then
      --device:emit_event(capabilities.switch.switch.off())
      --device:emit_event(capabilities.switchLevel.level(0))
      parent_device:set_field("LastWhite", 0, {persist = true})
      if rgbwl[device.parent_device_id].w == nil or rgbwl[device.parent_device_id].w == 0 then
        rgbwl[device.parent_device_id].w = 255
      end
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.WARM_WHITE, value = 0 },
        }
      })
      parent_device:send(set)
    elseif component == "red" then
      --device:emit_event(capabilities.switch.switch.off())
      --device:emit_event(capabilities.switchLevel.level(0))
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.RED, value = 0 },
        }
      })
      parent_device:send(set)
      if rgbwl[device.parent_device_id].g > 0 or rgbwl[device.parent_device_id].b > 0 then
        rgbwl[device.parent_device_id].r = 0
      end
    elseif component == "green" then
      --device:emit_event(capabilities.switch.switch.off())
      --device:emit_event(capabilities.switchLevel.level(0))
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.GREEN, value = 0 },
        }
      })
      parent_device:send(set)
      if rgbwl[device.parent_device_id].r > 0 or rgbwl[device.parent_device_id].b > 0 then
        rgbwl[device.parent_device_id].g = 0
      end
    elseif component == "blue" then
      --device:emit_event(capabilities.switch.switch.off())
      --device:emit_event(capabilities.switchLevel.level(0))
      local set = SwitchColor:Set({
        color_components = {
          { color_component_id=SwitchColor.color_component_id.BLUE, value = 0 },
        }
      })
      parent_device:send(set)
      if rgbwl[device.parent_device_id].g > 0 or rgbwl[device.parent_device_id].r > 0 then
        rgbwl[device.parent_device_id].b = 0
      end
    end

    parent_device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)

    local query = function()
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
      parent_device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
      parent_device:send(SwitchMultilevel:Get({}))
    end
    device.thread:call_with_delay(parent_device:get_field("Minimum_Delay"), query)
  end
end

---- switch_basic_report
local function switch_basic_report(driver,device,command)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<<< switch_basic_report >>>>")
    local endpoint = command.src_channel
    local value = command.args.value
    if  (endpoint == 0) then
      --if command.args.value == 0 then
      if command.args.value <= 1 then
        local set = Basic:Set({
          value = SwitchBinary.value.OFF_DISABLE,
        })
        device:send(set)

        device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.off())
        device:emit_component_event(device.profile.components["main"], capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(WHITE_ENDPOINT, capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(R_ENDPOINT, capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switchLevel.level(0))
        device:emit_event_for_endpoint(G_ENDPOINT, capabilities.switch.switch.off())
        device:emit_event_for_endpoint(B_ENDPOINT, capabilities.switchLevel.level(0))
        device:set_field("LastWhite", 0, {persist = true})
        device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0 )

        if device:get_field("Calculated_Delay") >= device:get_field("Minimum_Delay") then
          --emit child events
          value = 0
          command.component = "white"
          child_emit_event(driver, device, command, value)
          command.component = "red"
          child_emit_event(driver, device, command, value)
          command.component = "green"
          child_emit_event(driver, device, command, value)
          command.component = "blue"
          child_emit_event(driver, device, command, value)
        end
      else
        if device:get_field("Calculated_Delay") >= device:get_field("Minimum_Delay") then
          if device:get_field(LAST_COLOR_SWITCH_CMD_FIELD) > 0 then
            rgbwl[device.id].l = value
          end
          SwitchLevelDefaults.zwave_handlers[cc.SWITCH_MULTILEVEL][SwitchMultilevel.REPORT](driver, device, command)
          device:refresh()
        end
      end
    end
  end
end


----set_color_Temperature_handler
local function set_color_Temperature_handler(driver,device,command)

end

local function device_added(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:send(Association:Set({grouping_identifier = 5, node_ids = {self.environment_info.hub_zwave_id}}))
    device:refresh()
  else
    child_devices.device_added(self, device)
  end
end

local function endpoint_to_component(device, ep)
  if ep == 9 then --WHITE_ENDPOINT
    return "white"
  elseif ep == 6 then --R_ENDPOINT
    return "red"
  elseif ep == 7 then --G_ENDPOINT
    return "green"
  elseif ep == 8 then --B_ENDPOINT
      return "blue"
  else
    return "main"
  end
end

local function component_to_endpoint(device, component_id)
  if component_id == "white" then --WHITE_ENDPOINT= 9
    return 9
  elseif component_id == "red" then --R_ENDPOINT = 6
    return 6
  elseif component_id == "green" then --G_ENDPOINT= 7
    return 7
  elseif component_id == "blue" then --B_ENDPOINT= 8
      return 8
  else
    return {}
  end
end

local function device_init(self, device)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    --device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)
    if device.preferences.changeProfile1 == "Single" then
      device:try_update_metadata({profile = "fibaro-rgbw-controller"})
    else
      device:try_update_metadata({profile = "fibaro-rgbw-controller-multi"})
    end

    print("WHITE_ENDPOINT",WHITE_ENDPOINT)
    print("R_ENDPOINT",R_ENDPOINT)
    print("G_ENDPOINT",G_ENDPOINT)
    print("B_ENDPOINT",B_ENDPOINT)

    -- get forcedOnLevel parameter 157 value programmedSequence
    device:send(Configuration:Get({ parameter_number = 72 }))

    if device:get_field("LastWhite") == nil then
      device:set_field("LastWhite", 0, {persist = true})
    end

    rgbwl[device.id] = device:get_field("rgbwl".. device.id)
   
    if rgbwl[device.id] == nil then
      rgbwl[device.id] = {r = 100, g = 100, b = 100, w = 0, l = 100}
      print("<<< rgbwl[device.id].r", rgbwl[device.id].r)
      print("<<< rgbwl[device.id].g", rgbwl[device.id].g)
      print("<<< rgbwl[device.id].b", rgbwl[device.id].b)
      print("<<< rgbwl[device.id].w", rgbwl[device.id].w)
      print("<<< rgbwl[device.id].l", rgbwl[device.id].l)
      device:set_field("rgbwl".. device.id,rgbwl[device.id], {persist = true})
    end
      print("<<< rgbwl[device.id]", rgbwl[device.id])
      print("<<< rgbwl[device.id].r", rgbwl[device.id].r)
      print("<<< rgbwl[device.id].g", rgbwl[device.id].g)
      print("<<< rgbwl[device.id].b", rgbwl[device.id].b)
      print("<<< rgbwl[device.id].w", rgbwl[device.id].w)
      print("<<< rgbwl[device.id].l", rgbwl[device.id].l)
    end

    if device:get_field("Minimum_Delay") == nil or device:get_field("Calculated_Delay") == nil then
      set_delay(self, device)
      print("<<<< Minimum_Delay",device:get_field("Minimum_Delay"))
    end

    if device:get_field(LAST_COLOR_SWITCH_CMD_FIELD) == nil then
      device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)
    end

    --initialize variables to emit components state
    red[device.id], green[device.id], blue[device.id], white[device.id] = -1, -1, -1, -1
    
  end
  --This will print in the log the total memory in use by Lua in Kbytes
  print("Memory, count >>>>>>>",collectgarbage("count"), " Kbytes")
end

--programmed_Sequence_handler
local function programmed_Sequence_handler(self, device, command)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("programmed_Sequence Value", command.args.value)
    local programmed_Sequence_set = command.args.value
    device:emit_event(programmed_Sequence.programmedSequence(programmed_Sequence_set))
    
    local parameter_value = 1
    if programmed_Sequence_set == "Fireplace" then
      parameter_value = 6
    elseif programmed_Sequence_set == "Storm" then
      parameter_value = 7
    elseif programmed_Sequence_set == "Rainbow" then
      parameter_value = 8
    elseif programmed_Sequence_set == "Aurora" then
      parameter_value = 9
    elseif programmed_Sequence_set == "Police" then
      parameter_value = 10
    end

    device:send(Configuration:Set({parameter_number = 72, size = 1, configuration_value = parameter_value}))

    local query_color = function()
      --command.component = "main"
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.RED }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.GREEN }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.BLUE }))
      device:send(SwitchColor:Get({ color_component_id=SwitchColor.color_component_id.WARM_WHITE }))
      device:send(SwitchMultilevel:Get({}))
    end
    if parameter_value == 1 then
      device.thread:call_with_delay(2, query_color)
    else
      device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.on())
    end
    local query_off = function ()
      command.component = "main"
      device:set_field(LAST_COLOR_SWITCH_CMD_FIELD, 0)
      --initialize variables to emit components state
      red[device.id], green[device.id], blue[device.id], white[device.id] = -1, -1, -1, -1
      set_switch(self, device, command, 0)
      device:emit_component_event(device.profile.components["main"], capabilities.switch.switch.off())
    end
    if parameter_value == 1 then
      device.thread:call_with_delay(4, query_off)
    end
  end
end

-- emit programmed_Sequence read from device
local function configuration_report(driver, device, cmd)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local parameter_number = cmd.args.parameter_number
    local configuration_value = cmd.args.configuration_value

    if parameter_number == 72 then
      local programmed_Sequence_set = "Inactive"
      if configuration_value == 6 then
        programmed_Sequence_set = "Fireplace"
      elseif configuration_value == 7 then
        programmed_Sequence_set = "Storm"
      elseif configuration_value == 8 then
        programmed_Sequence_set = "Rainbow"
      elseif configuration_value == 9 then
        programmed_Sequence_set = "Aurora"
      elseif configuration_value == 10 then
        programmed_Sequence_set = "Police"
      end
      print("programmed_Sequence_set", programmed_Sequence_set)
      device:emit_event(programmed_Sequence.programmedSequence(programmed_Sequence_set))
    end
  end
end

local fibaro_rgbw_controller = {
  NAME = "Fibaro RGBW Controller",
  lifecycle_handlers = {
    added = device_added,
    init = device_init
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = set_switch_on,
      [capabilities.switch.commands.off.NAME] = set_switch_off
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = set_switch_level_handler,
    },
    [capabilities.colorTemperature.ID] = {
      [capabilities.colorTemperature.commands.setColorTemperature.NAME] = set_color_Temperature_handler
    },
    [capabilities.colorControl.ID] = {
      [capabilities.colorControl.commands.setColor.NAME] = set_color,
      [capabilities.colorControl.commands.setHue.NAME] = set_hue,
      [capabilities.colorControl.commands.setSaturation.NAME] = set_saturation
    },
    [programmed_Sequence.ID] = {
      [programmed_Sequence.commands.setProgrammedSequence.NAME] = programmed_Sequence_handler,
    },
  },
  zwave_handlers = {
    [cc.SWITCH_COLOR] = {
      [SwitchColor.REPORT] = switch_color_report
    },
    [cc.SWITCH_MULTILEVEL] = {
      [SwitchMultilevel.REPORT] = switch_multilevel_report
    },
    [cc.BASIC] = {
      [Basic.REPORT] = switch_basic_report
    },
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report
    },
  },
  can_handle = is_fibaro_rgbw_controller,
}

return fibaro_rgbw_controller
