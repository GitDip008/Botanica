// lib/navigation/config/beacon_map.dart
//
// The bridge between a physical PhytoSense ESP32 node and a place on the map.
//
// FILL THIS IN from the beacon team's table: for each node, its BLE id (the
// device MAC / advertised id the phone sees) mapped to the section/room it sits
// in. Once populated, the nearest-beacon positioning (positioning_provider.dart)
// lights up automatically — no other code change needed.
//
// Example once you have the table:
//   'AA:BB:CC:11:22:01': 'A12',   // node 1 sits in bed A12 (house A)
//   'AA:BB:CC:11:22:02': 'A8',
//   'AA:BB:CC:11:22:03': 'B3',
//
// The value is a floor-plan room label (A1..F4). The current-house glow is
// derived from its first letter, so even a house-level value like 'A' works.

const Map<String, String> kBeaconToSection = {
  // <beacon id> : <room label>,   // fill from the beacon team's node list
};
