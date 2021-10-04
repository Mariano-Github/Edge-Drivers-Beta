## Edge Driver Zigbee multi switch Zemismart

Author: Mariano Colmenarejo (Oct 2021)

## Fingerprint and Profile for lidl zigbee strip 3 plugs

 - It is in the testing phase.
 - It does not work well when the physical switch on the power strip is turned off and switch 1, main is off. All switches are turned off on  the device, but in the app, switches 2 and 3 do not update their off state until the periodic refresh arrives, adjusted every 3 minutes


## devices 04-oct-2021:
zigbeeManufacturer:
  - id: "LIDL/TS011F"
    deviceLabel: Lidl MultiPlug
    manufacturer: _TZ3000_1obwwnmq
    model: TS011F
    deviceProfileName: three-outlet
## tested by others users
  - id: "FeiBit/3-Switch" 
    deviceLabel: FeiBit 3 Switch
    manufacturer: FeiBit
    model: FNB56-ZSW03LX2.0
    deviceProfileName: three-switch

  - id: "3A Smart/LXN2S2" 
    deviceLabel: 3A Smart 2 Switch
    manufacturer: 3A Smart Home DE
    model: LXN-2S27LX1.0 
    deviceProfileName: two-switch
