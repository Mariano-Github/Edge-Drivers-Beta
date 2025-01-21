------- signal metrics emit event----

local capabilities = require "st.capabilities"
local last_signal_emit_time = os.time()

local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

local signal ={}

  -- emit signal metrics
  function signal.metrics(device, zb_rx)

    if os.time() - last_signal_emit_time > 27 then
      local visible_satate = device.preferences.signalMetricsVisibles
      local gmt = os.date("%Y/%m/%d Time: %H:%M",(os.time() + (device.preferences.localTimeOffset * 3600)))
      --local dni = string.format("0x%04X", zb_rx.address_header.src_addr.value)
      --local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. "<b>Date: </b>".. gmt .."<BR>"
      --metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
      local metrics = gmt .. ", LQI: ".. zb_rx.lqi.value .." ... rssi: ".. zb_rx.rssi.value
      device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))
      last_signal_emit_time = os.time()
    end
  end

return signal