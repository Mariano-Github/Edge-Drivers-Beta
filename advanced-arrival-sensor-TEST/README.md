## (NEW RELEASE) Beta Edge Drive Zigbee Advanced Arrival Sensor

Iman Haryadi, Hi Everyone,
- As a background, I had a couple ST arrival sensor from back in the day. I used them in my car to track my car come and go. We got an additional car and need a new sensor. I found that they are discontinued and very hard to find a used one.

I thought it would be fun to make one myself. I started to make one with the same functionality with the original ST arrival sensor with the following improvement. I use a recharge-able battery which will be filled up during a drive. I also use a powerful Zigbee module with an external module.

I added motion sensor and vibration sensor to help securing my car while it is parked outside the house.

This driver runs locally on the Hub, without need for an internet connection.  

Link to SmartThings Community presentation:

https://community.smartthings.com/t/introducing-advance-arrival-sensor/238282?u=mariano_colmenarejo


zigbeeManufacturer:

  - id: "SmartThings/tagv4"
    deviceLabel: Advanced Arrival Sensor tagv4
    manufacturer: SmartThings
    model: tagv4
    deviceProfileName: presence-temp-motion-acc-batt