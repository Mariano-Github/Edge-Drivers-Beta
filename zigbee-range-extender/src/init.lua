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

local Basic = (require "st.zigbee.zcl.clusters").Basic
local ZigbeeDriver = require "st.zigbee"
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

local do_refresh = function(self, device)
  device:send(Basic.attributes.ZCLVersion:read(device))
end

--applicationVersion_handler for signal metrics event
local function ZCLVersion_handler(self, device, value, zb_rx)
  print("ZCLVersion >>>>>>>>>",value.value)
  local visible_satate = false
    if device.preferences.signalMetricsVisibles == "Yes" then
      visible_satate = true
    end
    local lqi = zb_rx.lqi.value
    local rssi = zb_rx.rssi.value

    --local gmt = os.date("%Y/%m/%d Time: %H:%M",os.time())
    --local dni = string.format("0x%04X", zb_rx.address_header.src_addr.value)
    --local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
    --metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
    local metrics = "LQI: ".. lqi.."..RSSI: " .. rssi .."dbm"

    device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))
end

local zigbee_range_driver_template = {
  supported_capabilities = {
    capabilities.refresh
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    attr = {
      [Basic.ID] = {
        [Basic.attributes.ZCLVersion.ID] = ZCLVersion_handler,
      },
    },
  }
}

local zigbee_range_extender_driver = ZigbeeDriver("zigbee-range-extender", zigbee_range_driver_template)

function zigbee_range_extender_driver:device_health_check()
  local device_list = self.device_api.get_device_list()
  for _, device_id in ipairs(device_list) do
    local device = self:get_device_info(device_id, false)
    device:send(Basic.attributes.ZCLVersion:read(device))
  end
end
zigbee_range_extender_driver.device_health_timer = zigbee_range_extender_driver.call_on_schedule(zigbee_range_extender_driver, 300, zigbee_range_extender_driver.device_health_check)

zigbee_range_extender_driver:run()
