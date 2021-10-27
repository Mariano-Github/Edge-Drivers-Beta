## (NEW RELEASE) version 3.8 of the Edge Driver “Zigbee Level ColorTemp Bulb Mc”:

(This will be the last version of this driver as it will be integrated into another with colorControl capability)

- Added new profile for color temperature with range between 2000k and 6500k

## New Circadian Lighting Function as Custom Capability and can be activate and deactivate from automations or escenes:

- This Function requires the offset in hours of your local time with UTC time to be entered in preferences. Because the Lua functions for the Edge driver only return UTC time. If this is corrected, it will be removed.

- The active schedule for Circadian lighting will be from 5 a.m. at 7 p.m.

- The variation of Color temperature will be between 2700 k and the maximum value chosen in preferences between 3000k and 6000k

- The variation of intensity will be made between the minimum and maximum values ​​chosen in preferences by the user. The preferences “Turn On Start Level” and “Turn ON End Level” are used.

- The Color Temperature and Level values ​​are updated every 10 minutes

- Out of the active schedule, when the light is turned on it will turn on with the level and Color Temperature values ​​of the last shutdown. It can be manually changed and will remain until changed again or powered up within the active circadian lighting schedule.

## The priority logic of the different functions will be:

- If Random ON-OFF is Enabled:

Progressive ON and OFF are deactivated
Circadian Lighting is deactivated

- If Progressive ON and / or OFF is activated:

Random ON-OFF is deactivated
Circadian Lighting is deactivated
If Circadian Lighting is Activated:

Random ON-OFF is deactivated
Progressive ON and OFF is disabled

- If external commands of variation by steps of the Level or ColorTemp are sent:

All running Timers are stopped and the values ​​recived are kept
NO functions are disabled

- For each device paired to the driver, you can choose different functions and settings at the same time.

- As we already have the local time, I have changed the information for the next random change in the Random ON-OFF function. The time at which the next change will be made is now displayed. Thus it is reduced to a single event per change in history.


***********************************************************************************************

## (RELEASE) Version 3.6 of the Edge Driver "Zigbee Level ColorTemp Bulb Mc"

## Added in Preferences Option to Progressive Turn ON-OFF with ColorTemp increment or decrement.

When activated in Preferences, if you perform a progressive on or off, an increase or decrease of the Color Temperature will be applied according to the intensity level with this formula:

TempColor = (Level / 100 * 2300k) + 2700k

With this formula the color temperature will vary from 1% → 2723k to 100% → 5000k


*********************************************************************************************

## (NEW RELEASE): version 3.5 of the Edge Driver "Zigbee Level ColorTemp Bulb Mc"

## First of all, my thanks to @nayelyz for your help when I am stuck with a problem and @milandjurovic71 for your goods suggestions to improve this Driver.

In addition to the Custom Capabilities Random ON-OFF, Progressive-ON and OFF

## A new Custom Capability has been added to show information about the time remaining for the next random state change.
I had programmed to show the Time of the next random change, but in Lua I have not been able to show the Local Time, it only shows the UTC Time.

## Two new Custom Capabilities are added to be able to increase or decrease remotely the intensity Level and the Color Temperature step by step.
Suggestion of @milandjurovic71, in order to be able to partially replace the functions of the groovy smartapp “ABC Manager”:

- Switch Level Increase by steps: Eligible in Automations between -30% and + 30%

- Increase in Color Temperature in steps: Eligible in Automations between -500k and + 500k
Range for steps changes limited from 2700k to 6000k for valid range of the two Profiles without errors.
NOTE: In the Color Temperature steps when a value is changed, it does not exactly change that value due to a problem in the Edge Drive libraries with the conversion from Kelvin to Mireds and vice versa. Issue noted and looks like it will be fixed.

I’m going to change the name that appears in the drivers of my channel, adding -Mc, to differentiate them from the stock drivers or from other users.

## How am I going to publish it as a different driver you can install it using the driver change tool in the details menu of the Hub.

## As it has different Custom Capabilities, the first time a device with this Driver is installed, a FATAL error occurs in the Hub as it does not know the description of the capabilities. This error causes the driver to hang.
- To solve it, you have to reset or unplug the Hub, without uninstalling the device.
- Clear the cache of the app on the mobile.
- When the Hub is back online, Open the Device detaills, wait a bit and it will work.
- The following devices that are installed will no longer give an error and will be installed correctly.
- This problem I do not know if it will be solved after the Edge Drive beta phase


## Devices 27-oct-2021:

zigbeeManufacturer:
  - id: "LIDL/TS0502A"
    deviceLabel: Lidl Bulb
    manufacturer: _TZ3000_49qchf10
    model: TS0502A
    deviceProfileName: level-colortemp-2000-6500
  - id: "OSRAM/Classic"
    deviceLabel: OSRAM Classic
    manufacturer: OSRAM
    model: Classic A60 W clear - LIGHTIFY
    deviceProfileName: switch-level
  - id: "OSRAM/LIGHTIFY BR"
    deviceLabel: OSRAM LIGHTIFY BR
    manufacturer: OSRAM
    model: LIGHTIFY BR Tunable White
    deviceProfileName: level-colortemp-2700-6500
  - id: "Ecosmart-ZBT-A19-CCT"
    deviceLabel: Ecosmart-ZBT
    manufacturer: The Home Depot
    model: Ecosmart-ZBT-A19-CCT-Bulb
    deviceProfileName: level-colortemp-2700-6500
  - id: "Sengled/E11-G13"
    deviceLabel: Sengled E11-G13
    manufacturer: sengled
    model: E11-G13
    deviceProfileName: switch-level
  - id: "IKEA/Bulb E27 WW"
    deviceLabel: IKEA Bulb
    manufacturer: IKEA of Sweden
    model: TRADFRI bulb E27 WW 806lm
    deviceProfileName: switch-level
  - id: "IKEA/Bulb E27 WS"
    deviceLabel: IKEA Bulb
    manufacturer: IKEA of Sweden
    model: TRADFRI bulb E27 WS opal 980lm
    deviceProfileName: level-colortemp-2700-6000
  - id: "CREE/A-19-60W"
    deviceLabel: CREE A-19 60W
    manufacturer: CREE                            
    model: Connected A-19 60W Equivalent   
    deviceProfileName: switch-level
  - id: "OSRAM/LIGHTIFY A19"
    deviceLabel: OSRAM LIGHTIFY A19
    manufacturer: OSRAM
    model: LIGHTIFY A19 Tunable White
    deviceProfileName: level-colortemp-2700-6500
  - id: "Ecosmart-ZBT-BR30"
    deviceLabel: Ecosmart-ZBT-BR30
    manufacturer: The Home Depot
    model: Ecosmart-ZBT-BR30-CCT-Bulb
    deviceProfileName: level-colortemp-2700-6500
  - id: "OSRAM/CLA60-TW"
    deviceLabel: OSRAM CLA60-TW
    manufacturer: OSRAM
    model: CLA60 TW OSRAM
    deviceProfileName: level-colortemp-2700-6500
  - id: "OSRAM/Classic B40 TW"
    deviceLabel: OSRAM Classic B40 TW
    manufacturer: OSRAM
    model: Classic B40 TW - LIGHTIFY
    deviceProfileName: switch-level
  - id: "LEDVANCE/A60 TW"
    deviceLabel: LEDVANCE
    manufacturer: LEDVANCE A60 TW
    model: A60 TW Value II
    deviceProfileName: switch-level
zigbeeGeneric:
  - id: "dimmer-generic"
    deviceLabel: "Zigbee Dimmer"
    zigbeeProfiles: 
      - 0xC05E
    deviceIdentifiers: 
      - 0x0100
    clusters: 
      server: 
        - 0x0006
        - 0x0008
      client:
        - 0x0019
    deviceProfileName: switch-level