## (NEW RELEASE): Edge Driver Zigbee TempSensor and Thermostat Mc:

## This new Edge Driver allows you to convert a sensor that has the capability of Temperature into a fully programmable Thermostat that runs locally and usable with Routines and Scenes.

My thanks to @milandjurovic71 for his debugging work and for his always useful ideas and suggestions that it do possible build his idea of a fully operational virtual thermostat on the same driver.
Thanks also to @TAustin for helping me how make code for select which thermostat modes I want use and display.

## Zigbee devices that have at least the Capability of TemperatureMesurement can be used.

## This capability and all the others that the sensor has, motion, humidity, atmospheric pressure, contact … They have to use the Edge default libraries.

One Driver can control all sensors paired independently

For example, it has been tested with a SmartThings (Samjin) motion Sensor and Aqara Weather sensor.

## Thermostat Default Capabilities:
1. thermostatMode:
1.1. Asleep: Control Heat and Cool with Presets in Preferences for Heat and Cool Temperature
1.2. Away: Control Heat and Cool with Presets in Preferences for Heat and Cool Temperature
1.3. Auto: Control Heat and Cool with Presets in Heat Preferences for and Cool Temperature
1.4. Rush Hour: Control Heat and Cool with Presets in Preferences for Heat and Cool Temperature
1.5. Cool: Controls the temperature for Cooling with the set point entered manually.
1.6. Eco: Heat and Cool Control without Presets in Preferences for Heat and Cool Temperature
1.7. Heat: Controls the temperature for Heating with the set point entered manually.
1.8. Manual: Heat and Cool Control without Presets in Preferences for Heat and Cool Temperature
1.9. Off: Thermostat off. You can use fan On, Circulate, Scheduled modes

## 2. thermostatOperatingState:
2.1. Idle: Thermostat off, no temperature control
2.2. Heating: The current temperature is below the HeatSetPoint – Differential Temp
2.3. Pending Heat: The current temperature is above the HeatSetPoint – Temp Differential / 2
2.4. Cooling: The current temperature is above the CoolSetPoint + Temp Differential
2.5. Pending Cool: The current temperature is below the CoolSetPoint + Temp Differential / 2
2.6. Fan Only: Active Fan is selected and thermostat mode is Off
2.7. Vent economizer: Fan Circulate has been selected and the Thermostat Mode is Off.

## 3. thermostatFanMode:

3.1. Auto: Indicates that the fan will be activated automatically in the climate control.

If thermostat state are Pending Heat or Pending Cool then Fan Current status go to OFF.
If thermostat state are Heating or Cooling then Fan Current status go to ON.
3.2. On: The Fan will always be running in On mode.

Fan Only will be displayed under Thermostat Status If Thermostat Mode is Off.
if thermostat mode is different from off the status for heat or cool is displayed
3.3. Circulate: The Fan will always be running in Circulate mode.

Vent economizer: will be displayed under Thermostat Status if Thermostat Mode is Off.
if thermostat mode is different from off the heat or cool status is displayed
3.4. Followschedule: The Fan works with the on and off schedule according to the values, in minutes, chosen in preferences for Time On and Time Off. (Range between 1 and 60 min).

## 4. The Information Panels (Custom Capabilities):
4.1. Fan Current State: Indicates the Fan current Status On or Off, and can be used in Routines to activate fans, etc …
4.2. Fan Next State Change: Indicates the time at which the next scheduled Fan state change will occur.
To match your local time: Adjust the time difference with UTC time in preferences

In preferences you can program the temperature preset values for 4 thermostat modes.
This allows you to program with simple routines to vary the desired target temperatures for different Hours of the Day or for situations such as, I am away or vacation.

## How to Use the Preferences Start Stop Differential Temperature Setting:

It is used to adjust the desired temperature comfort and take advantage of the thermal inertia of your heating or cooling system.
This simulates the acceleration resistance of real mechanical thermostats.
The target temperature is subtracted the half of differential temperature (default 0.5) to stop the heating and in this way with the thermal inertia of the heat emitters the target temperature is not exceeded excessively.
The differential temperature (default 0.5) is subtracted of the target temperature to start the heating again. In this way a comfortable temperature difference is achieved without exceeding the target temperature.
For refrigeration it is the same but the temperature difference is added to the target temperature.
How to calculate our optimal differential temperature? :
With the minimum differential temperature (0.1º) we will observe the history of events and look for the temperature of the change to “Pending Heat” state and then we will look for the maximum temperature following that event.
The difference between the maximum temperature reached and that of the event of change to “Pending Heat” is approximately equivalent to the thermal inertia of our heating system with the temperature conditions that we have fixed in the electric emitters or water radiators.
That difference multiplied by 2 is the Differential Start-Stop temperature to be introduced in preferences.
Or any other that gives us the comfort we want.
For cooling in summer, we will perform the same operation.
In Next Picture an Example of calculate Thermal Inertia for Heat set Point 19ºC and Differential temp Start-Stop 0.5º:

Temperature for Pending Heat state= 18.8ºC
Max. Temperature after Temperature for Pending Heat state= 19.1ºC
Heat Thermal Inertia with Radiator water Temp 55ºC= 0.3ºC
Temperature differential for Start-Stop 0.6º aprox

Can see complete day temperature graphics in device detaills, and you can see the result of your automations and Temperature Set Points, in order to correct them if necessary to adjust the control to your needs.

When the device is installed for the first time:

It may be necessary to restart the Hub as it has custom capabilities.
The thermostat will not control the temperature until a first event of the current temperature is received. You can force an event by heating the sensor a little with your hand.
The sensor works with the default settings of temperature reports:
Minimum Interval: 30 sec
Maximum Interval: 300 sec
Reportable temperature change: 0.1ºC
Important considerations:

All sensors emit their reports inºC. As the maximum precision is 0.1ºC, the maximum precision in ºF will be 0.18ºF, which when rounded to 1 decimal place will be approximately 0.2ºF.
The values of the temperature presets have no units and the defaults are equivalent to ºC.
If your location use ºF, change the units to ºF in preferences and change the Heat and Cool values to equivalent values ºF.
The range for entering temperature in preferences is -50.0 to 250.0.
Decimal values can be used. this range covers the values required for ºC and ºF adjustments
The range to change the set point temperature in the thermostat and automations is from 0ºC to 40ºC and from 32ºF to 104ºF, with increments of +/-1º. This is due to the default presentation of the capability. If smartThings changes it to be able to enter decimals and expand the range it would be an improvement.

Every 15 seconds it does the temperature calculations for each paired sensor independently.
Therefore when making manual changes it may take a maximum of 15 sec to update the results and display them.

In the logcat you can check what data it is handling for the calculations:

2021-11-23T15:53:34.898053596+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  <<< Cheking Temp >>>

2021-11-23T15:53:34.904335262+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  device:      <ZigbeeDevice: 16fa2ff4-00ca-4b65-b1db-5af142511d65 [0x9CFB] (Termostato)>

2021-11-23T15:53:34.910679262+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  thermostat_Run =     running

2021-11-23T15:53:34.917512262+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  thermostatOperatingState Before =    heating

2021-11-23T15:53:34.924247929+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  thermostat_Mode =    rush hour

2021-11-23T15:53:34.930232929+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  thermostatFan_Mode = auto

2021-11-23T15:53:34.936408929+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  cycleCurrent =       stop

2021-11-23T15:53:34.943365929+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  device.preferences.floorRadaint =    No

2021-11-23T15:53:34.949794596+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  device.preferences.temperature DiffStarStop =        0.4

2021-11-23T15:53:34.955810596+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  *** Current_temp *** 19.7    Celsius

2021-11-23T15:53:34.962206596+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  ## heating_Setpoint ##       20.0

2021-11-23T15:53:34.968269596+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  tempChangeToHeating <=       19.6

2021-11-23T15:53:34.974496929+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  tempChangeToPendingHeat >    19.8

2021-11-23T15:53:34.981652262+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  ## cooling_Setpoint ##       24.0

2021-11-23T15:53:34.987896262+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  tempChangeToCooling >=       24.4

2021-11-23T15:53:34.993942262+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  tempChangeToPendingCool <    24.2

2021-11-23T15:53:35.000366596+00:00 PRINT Zigbee Temp Sensor with Thermostat v2.5  thermostatOperatingState ****        heating ****

2021-11-23T15:53:35.007746262+00:00 INFO Zigbee Temp Sensor with Thermostat v2.5  <ZigbeeDevice: 16fa2ff4-00ca-4b65-b1db-5af142511d65 [0x9CFB] (Termostato)> emitting event: {"state":{"value":"heating"},"component_id":"main","attribute_id":"thermostatOperatingState","capability_id":"thermostatOperatingState"}

2021-11-23T15:53:35.034710596+00:00 INFO Zigbee Temp Sensor with Thermostat v2.5  <ZigbeeDevice: 16fa2ff4-00ca-4b65-b1db-5af142511d65 [0x9CFB] (Termostato)> emitting event: {"state":{"value":"On"},"component_id":"main","attribute_id":"fanCyclicMode","capability_id":"legendabsolute60149.fanCyclicMode"}

2021-11-23T15:53:35.060864262+00:00 DEBUG Zigbee Temp Sensor with Thermostat v2.5  Termostato device thread event handled


## (NEW RELEASE) Version 2.0 of Edge Driver Zigbee Temp Sensor and Thermostat Mc:

## Improvements and bug fixes:

- As the driver runs locally, I have added corrections to prevent the temperature control Timer stopping, if a Reboot HUB occurs and the thermostat is running.
When the Hub is back online, it will continue to work with the settings it had.
This could happen unintentionally during a Hub firmware update.

- Added in preferences an adjustment for Underfloor Heating installation with the No, Heat (Heat only) and Heat & Cool options.
With this option the temperatures of the change to the Heating and / or Cooling state are corrected, to bring them closer to the set point Heat and Cool. In this way it begins to heat or cool earlier than in other air conditioning systems, to compensate that the underfloor heating system has more thermal inertia and takes longer to heat and cool the floor.

## (NEW RELEASE) Version 2.2 of Beta Edge Drive Zigbee Temp Sensor with Thermostat Mc

Thanks to @milandjurovic71, he had tested this new version of Driver.

Thanks to @GiacomoF, for suggesting to show atmospheric pressure in mBars to compensate for the low precision shown in kPa (10 mBar) , as could be seen in the groovy DTH.

## For sensors with capability of measuring atmospheric pressure, a Custom Capability is added to display the information in mBar.

It has been tested with an Aqara Weather and Smartthings Motion sensors.

To improve the information of Battery for Aqara sensors, the xiaomi_utils.lua that @Zach_Varberg shared in github repository has been used. Thanks

## List of supported devices (nov 23)

-id: “SmartThings-Motion-Sensor”
deviceLabel: ST Motion Sensor
manufacturer: Samjin
model: motion
deviceProfileName: motion-temp-therm-battery

-id: “lumi.weather”
deviceLabel: Aqara Weather
manufacturer: LUMI
model: lumi.weather
deviceProfileName: temp-humid-press-therm-battery

-id: “TUYATEC/RH3052”
deviceLabel: TUYATEC RH3052
manufacturer: TUYATEC-prhs1rsd
model: RH3052
deviceProfileName: temp-humid-therm-battery

id: "eWeLink/66666"
deviceLabel: Temp Humidity Sensor
manufacturer: eWeLink
model: 66666
deviceProfileName: temp-humid-therm-battery

id: “eWeLink/TH01” (Sonoff SNZB-02)
deviceLabel: Temp Humidity Sensor
manufacturer: eWeLink
model: TH01
deviceProfileName: temp-humid-therm-battery
