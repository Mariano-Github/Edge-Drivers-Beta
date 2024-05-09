local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
--local PowerConfiguration = clusters.PowerConfiguration
local ThermostatMode = capabilities.thermostatMode
local Thermostat = clusters.Thermostat
local SimpleMetering = clusters.SimpleMetering
local Status = require "st.zigbee.generated.types.ZclStatus"
local zcl_global_commands = require "st.zigbee.zcl.global_commands"

local ThermostatSystemMode      = Thermostat.attributes.SystemMode
--local ThermostatOperatingState = capabilities.thermostatOperatingState
--local utils             = require "st.utils"
local device_management = require "st.zigbee.device_management"

local THERMOSTAT_MODE_MAP = {
  [ThermostatSystemMode.OFF]               = ThermostatMode.thermostatMode.off,
  [ThermostatSystemMode.HEAT]              = ThermostatMode.thermostatMode.heat,
  [ThermostatSystemMode.AUTO]              = ThermostatMode.thermostatMode.auto
}

local IRIS_THERMOSTAT_FINGERPRINTS = {
  { mfr = "Twin-Star International", model = "20QI071ARA" }
}

local is_iris_duraflame_thermostat = function(opts, driver, device)
  for _, fingerprint in ipairs(IRIS_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("iris-duraflame")
      return true, subdriver
    end
  end
  return false
end

--- Update preferences after infoChanged recived ---
local function do_preferences (driver, device)
  for id, value in pairs(device.preferences) do
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      --if device.preferences.logDebugPrint == true then
        print("<< Preference changed name:",id,"oldPreferenceValue:",oldPreferenceValue, "newParameterValue: >>", newParameterValue)
      --end
      ------ Change profile 
      if id == "changeProfileIris" then
       if newParameterValue == "Multi" then
        device:try_update_metadata({profile = "thermostat-duraflame-multi"})
       elseif newParameterValue == "Single" then
        device:try_update_metadata({profile = "thermostat-duraflame"})
       end
      end
    end
  end
end

local thermostat_mode_handler = function(driver, device, thermostat_mode)
  if THERMOSTAT_MODE_MAP[thermostat_mode.value] then
    device:emit_event(THERMOSTAT_MODE_MAP[thermostat_mode.value]())
  end
end

local set_thermostat_mode = function(driver, device, command)
  if command.args.mode == "eco" then
    device:send_to_component(command.component, Thermostat.attributes.ThermostatProgrammingOperationMode:write(device, 0x04))
    device.thread:call_with_delay(1, function(d)
      device:send_to_component(command.component, Thermostat.attributes.ThermostatProgrammingOperationMode:read(device))
    end)
  else
    for zigbee_attr_val, st_cap_val in pairs(THERMOSTAT_MODE_MAP) do
      if command.args.mode == st_cap_val.NAME then
        device:send_to_component(command.component, Thermostat.attributes.SystemMode:write(device, zigbee_attr_val))
        -- deactivate ECO mode
        device:send_to_component(command.component, Thermostat.attributes.ThermostatProgrammingOperationMode:write(device, 0x00))
        device.thread:call_with_delay(1, function(d)
          device:send_to_component(command.component, Thermostat.attributes.SystemMode:read(device))
        end)
        break
      end
    end
  end
end

-- eco mode handler
local function thermostat_eco_mode_handler(driver, device, value)
  if  value.value == 0x04 then
    device:emit_event(capabilities.thermostatMode.thermostatMode("eco"))
  end
end

-- On handler
local function on_handler(driver, device, command)
  print("<<<< On command Handler >>>>")
  device:send_to_component(command.component, clusters.OnOff.server.commands.On(device))
  -- set Auto mode
  device:send_to_component(command.component, Thermostat.attributes.SystemMode:write(device, 0x01))
  -- deactivate ECO mode
  device:send_to_component(command.component, Thermostat.attributes.ThermostatProgrammingOperationMode:write(device, 0x00))
  device.thread:call_with_delay(1, function(d)
    device:send_to_component(command.component, Thermostat.attributes.SystemMode:read(device))
  end)
end

--- Command off handler ----
local function off_handler(driver, device, command)
  print("<<<< Off command Handler >>>>")  
  device:send_to_component(command.component, clusters.OnOff.server.commands.Off(device))
  -- set Off mode
  device:send_to_component(command.component, Thermostat.attributes.SystemMode:write(device, 0x00))
  -- deactivate ECO mode
  device:send_to_component(command.component, Thermostat.attributes.ThermostatProgrammingOperationMode:write(device, 0x00))
  device.thread:call_with_delay(1, function(d)
    device:send_to_component(command.component, Thermostat.attributes.SystemMode:read(device))
  end)
end

--- read zigbee attribute OnOff messages ----
local function on_off_attr_handler(driver, device, value, zb_rx)
  print ("function: on_off_attr_handler")

    --local src_endpoint = zb_rx.address_header.src_endpoint.value
    local attr_value = value.value
    --print ("src_endpoint =", zb_rx.address_header.src_endpoint.value , "value =", value.value)

    --- Emit event from zigbee message recived
    if attr_value == false or attr_value == 0 then
      device:emit_event(capabilities.switch.switch.off())
    elseif attr_value == true or attr_value == 1 then
      device:emit_event(capabilities.switch.switch.on())
    end
end

--- default_response_handler
local function default_response_handler(driver, device, zb_rx)
  print("<<<<<< default_response_handler >>>>>>")

  local status = zb_rx.body.zcl_body.status.value
  if status == Status.SUCCESS then
    local cmd = zb_rx.body.zcl_body.cmd.value
    local event = nil

    if cmd == clusters.OnOff.server.commands.On.ID then
      event = capabilities.switch.switch.on()
    elseif cmd == clusters.OnOff.server.commands.Off.ID then
      event = capabilities.switch.switch.off()
    end

    if event ~= nil then
      device:emit_event(event)
    end
  end
end

local function do_init(driver,device)
  device:emit_event(ThermostatMode.supportedThermostatModes({"off", "heat", "auto", "eco"}, { visibility = { displayed = false } }))
  -- set selected profile
  if device.preferences.changeProfileIris == "Single" then
    device:try_update_metadata({profile = "thermostat-duraflame"})
  elseif device.preferences.changeProfileIris == "Multi" then
    device:try_update_metadata({profile = "thermostat-duraflame-multi"})
  end
end

local function do_configure(self, device)
  device:send(device_management.build_bind_request(device, Thermostat.ID, self.environment_info.hub_zigbee_eui))
  device:send(Thermostat.attributes.LocalTemperature:configure_reporting(device, 10, 60, 50))
  device:send(Thermostat.attributes.OccupiedHeatingSetpoint:configure_reporting(device, 1, 600, 50))
  device:send(Thermostat.attributes.SystemMode:configure_reporting(device, 1, 0, 1))
  device:send(Thermostat.attributes.ThermostatProgrammingOperationMode:configure_reporting(device, 10, 300))
  device:send(device_management.build_bind_request(device, clusters.OnOff.ID, self.environment_info.hub_zigbee_eui))
  device:send(clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 600))
  device:send(device_management.build_bind_request(device, clusters.SimpleMetering.ID, self.environment_info.hub_zigbee_eui))
  device:send(clusters.SimpleMetering.attributes.InstantaneousDemand:configure_reporting(device, 1, 3600, 5))

  -- Additional one time configuration
    -- Divisor and multipler for PowerMeter
    device:send(SimpleMetering.attributes.Divisor:read(device))
    device:send(SimpleMetering.attributes.Multiplier:read(device))

  print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

local do_refresh = function(self, device)
  local attributes = {
    Thermostat.attributes.LocalTemperature,
    Thermostat.attributes.ThermostatProgrammingOperationMode,
    Thermostat.attributes.OccupiedHeatingSetpoint,
    Thermostat.attributes.SystemMode,
    clusters.OnOff.attributes.OnOff,
    clusters.SimpleMetering.attributes.InstantaneousDemand
  }
  for _, attribute in pairs(attributes) do
    device:send(attribute:read(device))
  end
end

local device_added = function(self, device)
  do_refresh(self, device)
end

local driver_switched = function(self, device)
  do_refresh(self, device)
  --do_configure(self, device)
  device.thread:call_with_delay(2, function() 
    do_configure(self,device)
    --print("doConfigure performed, transitioning device to PROVISIONED")
    --device:try_update_metadata({ provisioning_state = "PROVISIONED" })
  end)
end


local iris_duraflame_thermostat = {
  NAME = "IRIS DURAFLAME Thermostat",
  capability_handlers = {
    [ThermostatMode.ID] = {
      [ThermostatMode.commands.setThermostatMode.NAME] = set_thermostat_mode,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = on_handler,
      [capabilities.switch.commands.off.NAME] = off_handler
    },
  },
  zigbee_handlers = {
    global = {
      [clusters.OnOff.ID] = {
         [zcl_global_commands.DEFAULT_RESPONSE_ID] = default_response_handler
       }
     },
    attr = {
      [clusters.OnOff.ID] = {
        [clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
      },
      [Thermostat.ID] = {
        [Thermostat.attributes.SystemMode.ID] = thermostat_mode_handler,
        [Thermostat.attributes.ThermostatProgrammingOperationMode.ID] = thermostat_eco_mode_handler,
      }
    }
  },
  lifecycle_handlers = {
    init = do_init,
    driverSwitched = driver_switched,
    doConfigure = do_configure,
    added = device_added,
    infoChanged = do_preferences,
  },
  can_handle = is_iris_duraflame_thermostat
}

return  iris_duraflame_thermostat