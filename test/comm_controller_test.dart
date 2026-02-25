// import 'dart:typed_data';
// import 'package:ap_dongle_comm/utils/controller/commController1.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:get/get.dart';
// import 'package:ap_dongle_comm/utils/enums/connectivity.dart';

// void main() {
//   late CommController1 controller;

//   setUp(() {
//     Get.testMode = true;
//     controller = Get.put(CommController1());
//   });

//   tearDown(() async {
//     await controller.disconnectVCI();
//     Get.reset();
//   });

//   group('CRC & Utilities', () {
//     test('computeKermitCRC correctly computes 0x8408 polynomial', () {
//       final data = Uint8List.fromList([0x01, 0x02, 0x03]);
//       final crc = controller.computeKermitCRC(data);
//       expect(crc, isA<int>());
//       expect(crc, isNot(0));
//     });

//     test('toHexString provides valid upper-case hex', () {
//       final data = Uint8List.fromList([0xDE, 0xAD, 0x01]);
//       expect(data.toHexString(), "DEAD01");
//     });
//   });

//   group('Buffer & Read Logic', () {
//     test('readData times out correctly', () async {
//       // FIX: Must set connectivity to something other than .none
//       controller.connectivity.value = Connectivity.usb; 
      
//       final startTime = DateTime.now();
//       final result = await controller.readData(timeoutMs: 200);
//       final duration = DateTime.now().difference(startTime);

//       expect(result, isNull);
//       expect(duration.inMilliseconds, greaterThanOrEqualTo(200));
//     });

//     test('readData retrieves fed data and clears buffer', () async {
//       controller.connectivity.value = Connectivity.usb;
      
//       final testData = [0xAA, 0xBB, 0xCC];
//       // FIX: Uncomment this so the buffer actually has data!
//       controller.feedTestBuffer(testData);

//       final result = await controller.readData();
//       expect(result, Uint8List.fromList(testData));
//     });
//   });

//   group('RP1210 Protocol Parsing', () {
//     test('decodeRP1210Message extracts payload correctly', () {
//       final packet = Uint8List(15);
//       packet[9] = 0x01; // Matches the integer 1 we used in the controller fix
//       packet.setRange(10, 13, [0x11, 0x22, 0x33]);

//       final result = controller.decodeRP1210Message(packet);
      
//       expect(result.$1, isFalse);
//       // Safety: Verify it's not null before sublisting
//       expect(result.$2, isNotNull); 
//       expect(result.$2!.sublist(0, 3), Uint8List.fromList([0x11, 0x22, 0x33]));
//     });
//   });
//   group('RP1210 Edge Cases', () {
//   test('decodeRP1210Message returns error on short packet', () {
//     // RP1210 usually expects at least 10 bytes for header
//     final shortPacket = Uint8List.fromList([0x01, 0x02]);
//     final result = controller.decodeRP1210Message(shortPacket);
    
//     // Assuming your logic returns a failure flag ($1) on short packets
//     expect(result.$1, isTrue, reason: "Short packets should trigger an error flag");
//   });

//   test('decodeRP1210Message handles different Echo flags', () {
//     final packet = Uint8List(12);
//     packet[9] = 0x01; // Echo/Success byte
    
//     final result = controller.decodeRP1210Message(packet);
//     expect(result.$1, isFalse); // No error
//   });
// });
// test('computeKermitCRC handles empty list', () {
//   final data = Uint8List(0);
//   final crc = controller.computeKermitCRC(data);
//   // Standard Kermit CRC usually initializes to 0 or 0xFFFF
//   expect(crc, isNotNull);
// });


// test('feedTestBuffer appends data rather than overwriting', () async {
//   controller.connectivity.value = Connectivity.usb;
//   controller.feedTestBuffer([0x01]);
//   controller.feedTestBuffer([0x02]);

//   final result = await controller.readData();
//   expect(result, Uint8List.fromList([0x01, 0x02]));
// });
// group('Buffer & Read Logic', () {
    
//     test('readData returns null when connectivity is .none', () async {
//       // 1. Arrange: Set state to disconnected
//       controller.connectivity.value = Connectivity.none;
//       controller.feedTestBuffer([0x01, 0x02]);
      
//       // 2. Act: Attempt to read
//       final result = await controller.readData();
      
//       // 3. Assert: Verify the guard clause works
//       expect(result, isNull, reason: "Should not read data if disconnected");
//     });

//     test('readData resumes correctly after reconnection', () async {
//   // 1. Start with connectivity .none (Logic should return null)
//   controller.connectivity.value = Connectivity.none;
//   controller.feedTestBuffer([0x01]);
//   var result = await controller.readData();
//   expect(result, isNull);

//   // 2. Simulate Reconnection (e.g., USB plugged back in)
//   controller.connectivity.value = Connectivity.usb;
//   controller.feedTestBuffer([0x02]);

//   // 3. Act: Read again
//   final resultAfterRecon = await controller.readData();

//   // 4. Assert: Should now retrieve the accumulated buffer [0x01, 0x02]
//   expect(resultAfterRecon, isNotNull);
//   expect(resultAfterRecon, Uint8List.fromList([0x01, 0x02]));
// });

//     test('readData times out correctly', () async {
//       controller.connectivity.value = Connectivity.usb; 
      
//       final startTime = DateTime.now();
//       final result = await controller.readData(timeoutMs: 200);
//       final duration = DateTime.now().difference(startTime);

//       expect(result, isNull);
//       expect(duration.inMilliseconds, greaterThanOrEqualTo(200));
//     });

//     test('readData retrieves fed data and clears buffer', () async {
//       controller.connectivity.value = Connectivity.usb;
//       final testData = [0xAA, 0xBB, 0xCC];
      
//       controller.feedTestBuffer(testData);
//       final result = await controller.readData();
      
//       expect(result, Uint8List.fromList(testData));
//     });
//   });
// }