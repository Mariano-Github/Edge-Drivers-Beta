## (LAST RELEASE): Version 4.5 Edge Driver Zigbee TempSensor and Thermostat Mc:

Added control the thermostat with sevsral Temperature sensors paired in the same driver
Added option to Single or Multiple Tile

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

39882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  <<< Cheking Temp >>>
2021-11-08T14:33:06.666034882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  device:        <ZigbeeDevice: 9b6380e3-7155-4d74-85f6-0878a92e0a85 [0x68A5] (Sensor Mov-2)>
2021-11-08T14:33:06.672302882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostat_Run =       running
2021-11-08T14:33:06.678173882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostatOperatingState Before =      heating
2021-11-08T14:33:06.684129549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostat_Mode =      manual
2021-11-08T14:33:06.690717549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostatFan_Mode =   auto
2021-11-08T14:33:06.697209882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  cycleCurrent = stop
2021-11-08T14:33:06.703396549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  device.preferences.floorRadaint =      HeatCool
2021-11-08T14:33:06.709641215+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  device.preferences.temperature DiffStarStop =  0.8
2021-11-08T14:33:06.715798882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  *** Current_temp ***   16.5    Celsius
2021-11-08T14:33:06.721453882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  ## heating_Setpoint ## 20
2021-11-08T14:33:06.727510549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToHeating <= 19.542857142857
2021-11-08T14:33:06.733371215+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToPendingHeat >      19.6
2021-11-08T14:33:06.739948882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  ## cooling_Setpoint ## 27.0
2021-11-08T14:33:06.745869215+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToCooling >= 27.457142857143
2021-11-08T14:33:06.751975215+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToPendingCool <      27.4
2021-11-08T14:33:06.757758215+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostatOperatingState ****  heating ****
2021-11-08T14:33:06.765301215+00:00 INFO Zigbee Temp Sensor with Thermostat v2  <ZigbeeDevice: 9b6380e3-7155-4d74-85f6-0878a92e0a85 [0x68A5] (Sensor Mov-2)> emitting event: {"capability_id":"thermostatOperatingState","state":{"value":"heating"},"attribute_id":"thermostatOperatingState","component_id":"main"}
2021-11-08T14:33:06.793176216+00:00 INFO Zigbee Temp Sensor with Thermostat v2  <ZigbeeDevice: 9b6380e3-7155-4d74-85f6-0878a92e0a85 [0x68A5] (Sensor Mov-2)> emitting event: {"capability_id":"legendabsolute60149.fanCyclicMode","state":{"value":"On"},"attribute_id":"fanCyclicMode","component_id":"main"}
2021-11-08T14:33:06.819226882+00:00 DEBUG Zigbee Temp Sensor with Thermostat v2  Sensor Mov-2 device thread event handled
2021-11-08T14:33:07.334253549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  <<< Cheking Temp >>>
2021-11-08T14:33:07.363178882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  device:        <ZigbeeDevice: 075f38a5-5928-444b-ac8a-4563446777f4 [0x3F4D] (Sensor Mov-1)>
2021-11-08T14:33:07.381726216+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostat_Run =       running
2021-11-08T14:33:07.387930882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostatOperatingState Before =      pending heat
2021-11-08T14:33:07.418021216+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostat_Mode =      manual
2021-11-08T14:33:07.444130549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostatFan_Mode =   auto
2021-11-08T14:33:07.480930882+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  cycleCurrent = stop
2021-11-08T14:33:07.507754883+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  device.preferences.floorRadaint =      No
2021-11-08T14:33:07.531750216+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  device.preferences.temperature DiffStarStop =  0.8
2021-11-08T14:33:07.572001216+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  *** Current_temp ***   19.2    Celsius
2021-11-08T14:33:07.598180549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  ## heating_Setpoint ## 18
2021-11-08T14:33:07.643877883+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToHeating <= 17.2
2021-11-08T14:33:07.670585883+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToPendingHeat >      17.6
2021-11-08T14:33:07.723981216+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  ## cooling_Setpoint ## 25.0
2021-11-08T14:33:07.745488216+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToCooling >= 25.8
2021-11-08T14:33:07.763193549+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  tempChangeToPendingCool <      25.4
2021-11-08T14:33:07.785832883+00:00 PRINT Zigbee Temp Sensor with Thermostat v2  thermostatOperatingState ****  pending heat    ****
2021-11-08T14:33:07.800201883+00:00 INFO Zigbee Temp Sensor with Thermostat v2  <ZigbeeDevice: 075f38a5-5928-444b-ac8a-4563446777f4 [0x3F4D] (Sensor Mov-1)> emitting event: {"capability_id":"thermostatOperatingState","state":{"value":"pending heat"},"attribute_id":"thermostatOperatingState","component_id":"main"}
2021-11-08T14:33:07.845704216+00:00 INFO Zigbee Temp Sensor with Thermostat v2  <ZigbeeDevice: 075f38a5-5928-444b-ac8a-4563446777f4 [0x3F4D] (Sensor Mov-1)> emitting event: {"capability_id":"legendabsolute60149.fanCyclicMode","state":{"value":"Off"},"attribute_id":"fanCyclicMode","component_id":"main"}
2021-11-08T14:33:07.901099549+00:00 DEBUG Zigbee Temp Sensor with Thermostat v2  Sensor Mov-1 device thread event handled


## (NEW RELEASE) Version 2.0 of Edge Driver Zigbee Temp Sensor and Thermostat Mc:

## Improvements and bug fixes:

- As the driver runs locally, I have added corrections to prevent the temperature control Timer stopping, if a Reboot HUB occurs and the thermostat is running.
When the Hub is back online, it will continue to work with the settings it had.
This could happen unintentionally during a Hub firmware update.

- Added in preferences an adjustment for Underfloor Heating installation with the No, Heat (Heat only) and Heat & Cool options.
With this option the temperatures of the change to the Heating and / or Cooling state are corrected, to bring them closer to the set point Heat and Cool. In this way it begins to heat or cool earlier than in other air conditioning systems, to compensate that the underfloor heating system has more thermal inertia and takes longer to heat and cool the floor.

## (NEW RELEASE) Version 3.5 of Edge Driver Zigbee Temp Sensor and Thermostat Mc:
Improvements and bug fixes:

Added new profile for sensors with Illuminance capability (such as Environment Sensor)

Added new devices supported

Added custom presentations, with multiple tile, to show up to 5 different capacities in the tile depending of device profile. (Thanks to @Nayelyz for their help and engineering inquiries)

I would like to have put the capability of Thermostat Mode in the Tile, but I have not been able to why the presentation of the stock capacity is defined without information for the Dashboard view. Hopefully at some point they will add information from that capability to the mosaic.

## (NEW RELEASE): Version 4 of Zigbee Temp Sensor with Thermostat Mc: (May 22)

-At the request of @Luis_Mijares, the smartthings multipurpose sensors have been added to the driver:

-Full functionality of these sensors is maintained:

Contact

Temperature

Acceleration Sensor

Three Axes Acceleration

Use with garage door

## List of supported devices (May 2022)

See fingerprints.yml file