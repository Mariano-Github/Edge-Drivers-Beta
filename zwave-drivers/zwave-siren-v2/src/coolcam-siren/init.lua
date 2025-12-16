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
local cc  = require "st.zwave.CommandClass"
--local AlarmDefaults = require "st.zwave.defaults.alarm"
--local Basic = (require "st.zwave.CommandClass.Basic")({version=1})
--local Battery = (require "st.zwave.CommandClass.Battery")({version=1})
local Configuration = (require "st.zwave.CommandClass.Configuration")({version=1})

local siren_Sounds = capabilities ["legendabsolute60149.sirenSounds"]
local bell_Sounds = capabilities ["legendabsolute60149.bellSounds"]
local siren_Or_Bell_Active = capabilities ["legendabsolute60149.sirenOrBellActive"]




local function configuration_report(driver, device, cmd)
    print("<<<< configuration_report >>>>")
    local parameter_number = cmd.args.parameter_number
    local configuration_value = cmd.args.configuration_value

    local programmed_value = tostring(configuration_value)
    if parameter_number == 5 then

      --if configuration_value == 1 then
        --programmed_value = "Doorbell"
      --elseif configuration_value == 2 then
        --programmed_value = "Fur Elise"
      --elseif configuration_value == 3 then
        --programmed_value = "Doorbell Extended"
      --elseif configuration_value == 4 then
        --programmed_value = "Alert"
      --elseif configuration_value == 5 then
        --programmed_value = "William Tell"
      --elseif configuration_value == 6 then
        --programmed_value = "Rondo Alla Turca"
      --elseif configuration_value == 7 then
        --programmed_value = "Police Siren"
      --elseif configuration_value == 8 then
        --programmed_value = "Evacuation"
      --elseif configuration_value == 9 then
        --programmed_value = "Beep Beep"
      --elseif configuration_value == 10 then
       --programmed_value = "Beep"

      print("Siren programmed_value", programmed_value)
      device:emit_event(siren_Sounds.sirenSounds(programmed_value))
    elseif parameter_number == 6 then
      print("Bell programmed_value", programmed_value)
      device:emit_event(bell_Sounds.bellSounds(programmed_value))
    elseif parameter_number == 7 then
      print("Siren or Bell programmed_value", programmed_value)
      device:emit_event(siren_Or_Bell_Active.sirenOrBellActive(programmed_value))
    end
end

local function device_init(driver, device)
  -- get siren Sound and bell sound parameter 5, 6 and 7
  device:send(Configuration:Get({ parameter_number = 5 }))
  device:send(Configuration:Get({ parameter_number = 6 }))
  device:send(Configuration:Get({ parameter_number = 7 }))

end

local function siren_sounds_handler(driver, device, command)
  print("siren_sounds Value", command.args.value)

  local sound_value = tonumber(command.args.value)
  device:emit_event(siren_Sounds.sirenSounds(command.args.value))

  --send parameter value
  device:send(Configuration:Set({parameter_number = 5, size = 1, configuration_value = sound_value}))

  local query = function()
    device:send(Configuration:Get({ parameter_number = 5 }))
  end
  device.thread:call_with_delay(2, query)

end

local function bell_sounds_handler(driver, device, command)
  print("bell_sounds Value", command.args.value)
  
  local sound_value = tonumber(command.args.value)
  device:emit_event(bell_Sounds.bellSounds(command.args.value))

  --send parameter value
  device:send(Configuration:Set({parameter_number = 6, size = 1, configuration_value = sound_value}))

  local query = function()
    device:send(Configuration:Get({ parameter_number = 6 }))
  end
  device.thread:call_with_delay(2, query)
end

---siren_Or_Bell_Active_handler
local function siren_Or_Bell_Active_handler(driver, device, command)
  print("siren_Or_Bell_Active Value", command.args.value)
  
  local value = tonumber(command.args.value)
  device:emit_event(siren_Or_Bell_Active.sirenOrBellActive(command.args.value))

  --send parameter value
  device:send(Configuration:Set({parameter_number = 7, size = 1, configuration_value = value}))

  local query = function()
    device:send(Configuration:Get({ parameter_number = 7 }))
  end
  device.thread:call_with_delay(2, query)
end

local coolcam_siren = {
  NAME = "coolcam-siren",
  can_handle = require("coolcam-siren.can_handle"),
  capability_handlers = {
    [siren_Sounds.ID] = {
      [siren_Sounds.commands.setSirenSounds.NAME] = siren_sounds_handler,
    },
    [bell_Sounds.ID] = {
      [bell_Sounds.commands.setBellSounds.NAME] = bell_sounds_handler,
    },
    [siren_Or_Bell_Active.ID] = {
      [siren_Or_Bell_Active.commands.setSirenOrBellActive.NAME] = siren_Or_Bell_Active_handler,
    },
  },
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report
    },
  },
  lifecycle_handlers = {
    --added = device_added
    init = device_init
  }
}

return coolcam_siren
