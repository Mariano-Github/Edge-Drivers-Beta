------- signal metrics emit event----

local capabilities = require "st.capabilities"

local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

local signal ={}

  -- emit signal metrics
  function signal.metrics(device, zb_rx)
    local visible_satate = false
    if device.preferences.signalMetricsVisibles == "Yes" then
      visible_satate = true
    end
    
    local gmt = os.date("%Y/%m/%d GMT: %H:%M",os.time())
    local metrics = gmt .. ", LQI: ".. zb_rx.lqi.value .." ... rssi: ".. zb_rx.rssi.value
    device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))
  end

return signal