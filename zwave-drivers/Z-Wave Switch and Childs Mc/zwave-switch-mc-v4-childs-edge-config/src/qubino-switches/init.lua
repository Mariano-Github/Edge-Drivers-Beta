local capabilities = require "st.capabilities"
--- @type st.utils
--local utils = require "st.utils"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({version=3})
--- @type st.zwave.CommandClass.SensorMultilevel
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({version=5})
--- @type st.zwave.CommandClass.SwitchMultilevel
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({version=4})
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=1})
--local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })

local constants = require "qubino-switches/constants/qubino-constants"
local child_devices = require "child-devices"

local QUBINO_FINGERPRINTS = {
  {mfr = 0x0159, prod = 0x0001, model = 0x0051, deviceProfile = "qubino-flush-dimmer"}, -- Qubino Flush Dimmer
  {mfr = 0x0159, prod = 0x0001, model = 0x0052, deviceProfile = "qubino-din-dimmer"}, -- Qubino DIN Dimmer
  {mfr = 0x0159, prod = 0x0001, model = 0x0053, deviceProfile = "qubino-flush-dimmer-0-10V"}, -- Qubino Flush Dimmer 0-10V
  {mfr = 0x0159, prod = 0x0001, model = 0x0055, deviceProfile = "qubino-mini-dimmer"},  -- Qubino Mini Dimmer
  {mfr = 0x0159, prod = 0x0002, model = 0x0051, deviceProfile = "qubino-flush2-relay"}, -- Qubino Flush 2 Relay
  {mfr = 0x0159, prod = 0x0002, model = 0x0052, deviceProfile = "qubino-flush1-relay"}, -- Qubino Flush 1 Relay
  {mfr = 0x0159, prod = 0x0002, model = 0x0053, deviceProfile = "qubino-flush1d-relay"}  -- Qubino Flush 1D Relay
}

local function getDeviceProfile(device, isTemperatureSensorOnboard)
  local newDeviceProfile
  for _, fingerprint in ipairs(QUBINO_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      newDeviceProfile = fingerprint.deviceProfile
      if(isTemperatureSensorOnboard) then
        return newDeviceProfile.."-temperature"
      else
        return newDeviceProfile
      end
    end
  end
  return nil
end

local function can_handle_qubino_flush_relay(opts, driver, device, cmd, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  --return device.zwave_manufacturer_id == constants.QUBINO_MFR
  if device:id_match(constants.QUBINO_MFR) then
    local subdriver = require("qubino-switches")
    return true, subdriver
  end
  return false
end

local function add_temperature_sensor_if_needed(device)
  if not (device:supports_capability_by_id(capabilities.temperatureMeasurement.ID)) then
    local new_profile = getDeviceProfile(device, true)
    device:try_update_metadata({profile = new_profile})
  end
end

local function sensor_multilevel_report(self, device, cmd)
  if (cmd.args.sensor_type == SensorMultilevel.sensor_type.TEMPERATURE) then
    local scale = 'C'
    if (cmd.args.sensor_value > constants.TEMP_SENSOR_WORK_THRESHOLD) then
      add_temperature_sensor_if_needed(device)
      if (cmd.args.scale == SensorMultilevel.scale.temperature.FARENHEIT) then
        scale = 'F'
      end
      device:emit_event_for_endpoint(
        cmd.src_channel,
        capabilities.temperatureMeasurement.temperature({value = cmd.args.sensor_value, unit = scale})
      )
    end
  end
end

local do_refresh = function(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    if device:supports_capability_by_id(capabilities.switchLevel.ID) then
      device:send(SwitchMultilevel:Get({}))
    end
    for component, _ in pairs(device.profile.components) do 
      if device:supports_capability_by_id(capabilities.powerMeter.ID, component) then
        device:send_to_component(Meter:Get({scale = Meter.scale.electric_meter.WATTS}), component)
      end
      if device:supports_capability_by_id(capabilities.energyMeter.ID, component) then
        device:send_to_component(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS}), component)
      end
      if device:supports_capability_by_id(capabilities.switch.ID, component) then
        device:send_to_component(SwitchBinary:Get({}), component)
      end
    end
    if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
      if device.profile.components["extraTemperatureSensor"] ~= nil then
        device:send_to_component(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE}), "extraTemperatureSensor")
      else
        device:send(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE}))
      end
    end
  end
end

local function device_added(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    --local association_cmd = Association:Set({grouping_identifier = 2, node_ids = {self.environment_info.hub_zwave_id}})
    -- This command needs to be sent before creating component
    -- That's why MultiChannel is forced here
    --local endpoint = 3
    --if device.zwave_manufacturer_id == 0x0159 and device.zwave_product_type == 0x0002 and device.zwave_product_id == 0x0052 then endpoint = 4 end -- Qubino Flush 1 Relay
    --association_cmd.dst_channels = {endpoint}
    --device:send(association_cmd)
    do_refresh(self, device)
  else
    child_devices.device_added(self, device)
  end
end

local qubino_relays = {
  NAME = "Qubino Relays",
  can_handle = can_handle_qubino_flush_relay,
  zwave_handlers = {
    [cc.SENSOR_MULTILEVEL] = {
      [SensorMultilevel.REPORT] = sensor_multilevel_report
    }
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    }
  },
  lifecycle_handlers = {
    added = device_added
  },
  sub_drivers = {
    require("qubino-switches/qubino-relays"),
    require("qubino-switches/qubino-dimmer")
  }
}

return qubino_relays