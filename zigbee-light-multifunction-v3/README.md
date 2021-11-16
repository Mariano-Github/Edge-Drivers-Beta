## (New RELEASE) New Edge Drive Zigbee Light Multifunction Mc:

- This Driver has all the functions of the Zigbee Level ColorTemp Bulb Mc driver, which it replaces and will not be updated any more.

## Added Color Control Capability with profiles for RGB and RGBW with 2700k-6500k Color temperature.

Thanks to the suggestion and collaboration to do the tests for @milandjurovic71

## (NEW RELEASE) Version 2.0 of the Edge Driver Zigbee Light Multifunction Mc

## Improvements and bug fixes:

At the request of @milandjurovic71, preferences have been added for Minimum and Maximum Level settings of the Circadian Lighting function. In this way they are independent of the Llevel settings for progressive ON

The code has been corrected to prevent the “ Active " selections of the Progressive ON-OFF and Circadian Lighting functions from being reset to " Inactive " when a Reboot Hub or Driver update happens.

## (NEW RELEASE) Version 3.0 of the Edge Driver Zigbee Light Multifunction Mc

## Improvements and bug fixes:

My Thanks to @milandjurovic71 for test the driver with his bulbs.

As a request, @eric182 , the Continuous Color Change function has been added:

-Has a Custom Capability to turn the function Active and Inactive.

-Has a Custom Capability to modify the Timer between 1 and 20 sec for Color Changes

-Has a Custom Capability to select Color Change Mode

-Continuous Mode : The initial color is adjusted randomly and changes continuously with the rhythm of the timer chosen between 1 and 20 Sec.

-Random Mode : Color is adjusted randomly continuously with each timer interval

-All Modes : Both modes run randomly for a time between 50 sec to 300 sec each random cycle. Color change with random timer between 1 and 3 seconds.

-All three capabilities are accessible for use with routines and scenes
Color change timer and color change mode can be modified dynamically.

IMPORTANT: As Driver have new custom Capabiliies you may have to do a HUB reboot when you install it for the first time.
You do not need to uninstall the device, just clear the app cache and when the hub is online it will work



## Works with lights, led strips with profiles:

Switch & Level
Switch, Level & ColorTemperature
Switch, Level, RGB, RGBW, RGBCCT, CCT
Could work with zigbee single dimmers, but not tested

## Included Devices :

id: “LIDL/TS0502A”
deviceLabel: Lidl Bulb
manufacturer: _TZ3000_49qchf10
model: TS0502A
deviceProfileName: level-colortemp-2000-6500

id: “OSRAM/Classic”
deviceLabel: OSRAM Classic
manufacturer: OSRAM
model: Classic A60 W clear - LIGHTIFY
deviceProfileName: switch-level

id: “OSRAM/LIGHTIFY BR”
deviceLabel: OSRAM LIGHTIFY BR
manufacturer: OSRAM
model: LIGHTIFY BR Tunable White
deviceProfileName: level-colortemp-2700-6500

id: “Ecosmart-ZBT-A19-CCT”
deviceLabel: Ecosmart-ZBT
manufacturer: The Home Depot
model: Ecosmart-ZBT-A19-CCT-Bulb
deviceProfileName: level-colortemp-2700-6500

id: “Sengled/E11-G13”
deviceLabel: Sengled E11-G13
manufacturer: sengled
model: E11-G13
deviceProfileName: switch-level

id: “IKEA/Bulb E27 WW”
deviceLabel: IKEA Bulb
manufacturer: IKEA of Sweden
model: TRADFRI bulb E27 WW 806lm
deviceProfileName: switch-level


id: “IKEA/Bulb E27 WS”
deviceLabel: IKEA Bulb
manufacturer: IKEA of Sweden
model: TRADFRI bulb E27 WS opal 980lm
deviceProfileName: level-colortemp-2700-6000

id: “CREE/A-19-60W”
deviceLabel: CREE A-19 60W
manufacturer: CREE
model: Connected A-19 60W Equivalent
deviceProfileName: switch-level

id: “OSRAM/LIGHTIFY A19”
deviceLabel: OSRAM LIGHTIFY A19
manufacturer: OSRAM
model: LIGHTIFY A19 Tunable White
deviceProfileName: level-colortemp-2700-6500

id: “Ecosmart-ZBT-A19-BR30”
deviceLabel: Ecosmart-ZBT-BR30
manufacturer: The Home Depot
model: Ecosmart-ZBT-A19-BR30-CCT-Bulb
deviceProfileName: level-colortemp-2700-6500

id: “OSRAM/CLA60-TW”
deviceLabel: OSRAM CLA60-TW
manufacturer: OSRAM
model: CLA60 TW OSRAM
deviceProfileName: level-colortemp-2700-6500

id: “OSRAM/Gardenspot RGB”
deviceLabel: OSRAM Gardenspot RGB
manufacturer: OSRAM
model: LIGHTIFY Gardenspot RGB
deviceProfileName: level-rgb

id: “OSRAM/Flex RGBW”
deviceLabel: OSRAM Flex RGBW
manufacturer: OSRAM
model: LIGHTIFY Flex RGBW
deviceProfileName: rgbw-level-colortemp-2700-6500

id: “GLEDOPTO/GL-C-008S”
deviceLabel: GLEDOPTO GL-C-008S
manufacturer: GLEDOPTO
model: GL-C-008S
deviceProfileName: rgbw-level-colortemp-2700-6500

id: “GLEDOPTO/GL-C-008P”
deviceLabel: GLEDOPTO GL-C-008P
manufacturer: GLEDOPTO
model: GL-C-008P
deviceProfileName: rgbw-level-colortemp-2700-6500

id: “3A-Smart-Home/LS27LX1.7”
deviceLabel: 3A Smart LXT56-LS27LX1.7
manufacturer: 3A Smart Home DE
model: LXT56-LS27LX1.7
deviceProfileName: rgbw-level-colortemp-2700-6500

id: “GLEDOPTO/GL-B-001ZS”
deviceLabel: GLEDOPTO GL-B-001ZS
manufacturer: GLEDOPTO
model: GL-B-001ZS
deviceProfileName: rgbw-level-colortemp-2700-6500

id: “OSRAM/Classic B40 TW”
deviceLabel: OSRAM Classic B40 TW
manufacturer: OSRAM
model: Classic B40 TW - LIGHTIFY
deviceProfileName: level-colortemp-2700-6500

id: “LEDVANCE/A60 TW”
deviceLabel: LEDVANCE A60 TW
manufacturer: LEDVANCE
model: A60 TW Value II
deviceProfileName: level-colortemp-2700-6500

id: "FeiBit/ZSC05HG1.0"
deviceLabel: FeiBit Dimmer
manufacturer: Feibit Inc co.
model: FB56+ZSC05HG1.0
deviceProfileName: switch-level

id: "sengled/E11-N1EA"
deviceLabel: sengled E11-N1EA
manufacturer: sengled
model: E11-N1EA
deviceProfileName: rgbw-level-colortemp-2700-6500

id: "lk/Bulb M3500107"
deviceLabel: lK Bulb
manufacturer: lk
model: ZBT-CCTLight-M3500107
deviceProfileName: level-colortemp-2700-6000

id: "IKEA/Bulb E26 opal"
deviceLabel: IKEA Bulb
manufacturer: IKEA of Sweden
model: TRADFRI bulb E26 opal 1000lm
deviceProfileName: switch-level
zigbeeGeneric:

id: "dimmer-generic ZLL"
deviceLabel: “Zigbee Dimmer”
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

id: "dimmer-generic"
deviceLabel: “Zigbee Dimmer”
zigbeeProfiles:
- 0x0104
deviceIdentifiers:
- 0x0101
clusters:
server:
- 0x0006
- 0x0008
client:
- 0x0000
deviceProfileName: switch-level

id: "dimmer-generic-1"
deviceLabel: “Zigbee Dimmer”
zigbeeProfiles:
- 0x0104
deviceIdentifiers:
- 0x0101
clusters:
server:
- 0x0006
- 0x0008
client:
- 0x0019
deviceProfileName: switch-level

id: "RGBW ZLL-generic"
deviceLabel: “Zigbee RGBW ZLL”
zigbeeProfiles:
- 0xC05E
deviceIdentifiers:
- 0x0210
clusters:
server:
- 0x0006
- 0x0008
- 0x0300
client:
- 0x0019
deviceProfileName: rgbw-level-colortemp-2700-6500