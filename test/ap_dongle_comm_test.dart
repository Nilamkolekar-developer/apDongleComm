// import 'dart:developer';
// import 'dart:typed_data';
// import 'package:ap_dongle_comm/utils/controller/dongleController1.dart';
// import 'package:ap_dongle_comm/utils/enums/command_ids.dart';
// import 'package:ap_dongle_comm/utils/enums/connectivity.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:get/get.dart';

// import 'package:ap_dongle_comm/utils/controller/commController1.dart';
// import 'package:ap_dongle_comm/utils/enums/protocol.dart';
// import 'package:ap_dongle_comm/utils/helper/can_converters.dart';


// // --- MOCK IMPLEMENTATION ---
// // This allows the test to run without a real USB/BLE connection
// class MockCommController extends CommController1 {
//  Uint8List? mockResponse;
//   Uint8List? lastSentCommand; // Field to capture outgoing bytes
// Uint8List? Function(Uint8List)? onSendCommand;
// Uint8List? Function()? onReadResponse;
//   @override
//   Future<Uint8List?> sendCommand(Uint8List command) async {
//     lastSentCommand = command; // Store the command being sent
//     log("Mock sending: ${CanConverters.bytesToHex(command)}");
//     if (onSendCommand != null) {
//       // Note: We'll simulate the return of the bytes that 
//       // ResponseArrayDecoding expects.
//       return onSendCommand!(command);
//     }
//     // Return a dummy ACK [20, 01, 01, 00, 00, 00]
//     return mockResponse ?? Uint8List.fromList([0x20, 0x01, 0x01, 0x00, 0x00, 0x00]);
//   }
//   void setMockResponse(Uint8List response) {
//     mockResponse = response;
//   }

//   @override
//   Future<Uint8List?> readData({int timeoutMs = 2000}) async {
//     return mockResponse;
//   }
//   @override
//   Future<Uint8List?> readResponse() async {
//     // This mimics the hardware being asked for data without a new command
//     if (onReadResponse != null) return onReadResponse!();
//     return null; 
//   }
// }

// void main() {
//   late MockCommController mockController;
//   late DongleController dongleComm;

//   setUp(() {
//     Get.testMode = true;
    
//     // Initialize as the specific Mock type
//     mockController = MockCommController();
    
//     // Inject it into GetX as the base class type
//     Get.put<CommController1>(mockController);

//     // Default instance for basic tests
//     dongleComm = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN);
//   });

//   tearDown(() {
//     Get.reset();
//   });

//   group('dongleComm Command Construction (Branching)', () {
    
//     test('Reset: Channel Mode (isChannel: true) -> 2001 prefix', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       await dongle.dongleReset();
      
//       // Verify outgoing bytes captured by the mock
//       final sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("DEBUG Sent (Channel): $sentHex");
//       // Command: 2001 + 01 (ID) + 01 (Sub)
//       expect(sentHex.startsWith("20010101"), isTrue);
//     });

//     test('Reset: Standard Mode (isChannel: false) -> 2003 prefix', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       await dongle.dongleReset();
      
//       final sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("DEBUG Sent (Standard): $sentHex");
//       // Command: 2003 + 01 (Sub)
//       expect(sentHex.startsWith("200301"), isTrue);
//     });
//   });

//   group('Hard RX Header Mask Padding', () {
//     test('Pads 11-bit ID (7E8) to 4 chars (07E8)', () async {
//       final result = await dongleComm.canSetHardRxHeaderMask("7E8");
//       final hex = CanConverters.bytesToHex(result).replaceAll(' ', '').toUpperCase();
      
//       // Logic: 2003 + 01 (Chan) + 20 (Sub) + 07E8 (Padded Data)
//       expect(hex.contains("07E8"), isTrue);
//       expect(hex.startsWith("20030120"), isTrue);
//     });

//     test('Pads 29-bit ID (12345) to 8 chars (00012345)', () async {
//       final result = await dongleComm.canSetHardRxHeaderMask("12345");
//       final hex = CanConverters.bytesToHex(result).replaceAll(' ', '').toUpperCase();
      
//       // Logic: 2005 (Length changed for extended) + 01 + 20 + 00012345
//       expect(hex.contains("00012345"), isTrue);
//       expect(hex.startsWith("20050120"), isTrue);
//     });
//   });
//   test('SetProtocol: Channel Mode (isChannel: true) -> 2002 prefix', () async {
//     // 1. Setup
//     final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
//     int testProtocol = 6; // e.g., ISO15765_500KB_11BIT_CAN
    
//     // 2. Execute
//     await dongle.dongleSetProtocol(testProtocol);
    
//     // 3. Verify outgoing bytes
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toUpperCase();

//     print("SENT Protocol Hex (Channel): $sentHex");
    
//     // Structure: 2002 (Hdr) + 01 (Chan) + 02 (Sub) + 06 (Proto)
//     expect(sentHex.startsWith("2002010206"), isTrue);
//   });

//   test('SetProtocol: Standard Mode (isChannel: false) -> 2004 prefix', () async {
//     // 1. Setup
//     final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
//     int testProtocol = 2; // e.g., J1850 PWM
    
//     // 2. Execute
//     await dongle.dongleSetProtocol(testProtocol);
    
//     // 3. Verify outgoing bytes
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toUpperCase();

//     print("SENT Protocol Hex (Standard): $sentHex");
    
//     // Structure: 2004 (Hdr) + 02 (Sub) + 02 (Proto)
//     expect(sentHex.startsWith("20040202"), isTrue);
//   });

//   // --- GET PROTOCOL COMMAND TESTS ---

//     test('GetProtocol: Channel Mode (isChannel: true) uses 2001 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // 2. Execute
//       await dongle.dongleGetProtocol();
      
//       // 3. Verify outgoing bytes
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetProtocol Hex (Channel): $sentHex");
      
//       // Expect: 2001 (Hdr) + 01 (Chan) + 03 (Sub-function for GetProtocol)
//       // The total length should be 4 bytes + 2 bytes CRC = 12 hex chars
//       expect(sentHex.startsWith("20010103"), isTrue);
//     });

//     test('GetProtocol: Standard Mode (isChannel: false) uses 2003 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       // 2. Execute
//       await dongle.dongleGetProtocol();
      
//       // 3. Verify outgoing bytes
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetProtocol Hex (Standard): $sentHex");
      
//       // Expect: 2003 (Hdr) + 03 (Sub-function for GetProtocol)
//       // The total length should be 3 bytes + 2 bytes CRC = 10 hex chars
//       expect(sentHex.startsWith("200303"), isTrue);
//     });

//     // --- GET FIRMWARE VERSION COMMAND TESTS ---

//     test('GetFirmware: Channel Mode (isChannel: true) uses 2001 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // 2. Execute
//       await dongle.dongleGetFirmwareVersion();
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetFirmware Hex (Channel): $sentHex");
      
//       // Expect: 2001 (Hdr) + 01 (Chan) + 14 (Sub-function)
//       expect(sentHex.startsWith("20010114"), isTrue);
//     });

//     test('GetFirmware: Standard Mode (isChannel: false) uses 2003 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       // 2. Execute
//       await dongle.dongleGetFirmwareVersion();
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetFirmware Hex (Standard): $sentHex");
      
//       // Expect: 2003 (Hdr) + 14 (Sub-function)
//       expect(sentHex.startsWith("200314"), isTrue);
//     });

//     // --- FOTA COMMAND TESTS ---

//    test('SetFota: Correctly formats packet with sub-function 0x19 and ASCII payload', () async {
//   final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN);
//   String fotaCmd = "ABC"; 

//   await dongle.dongleSetFota(fotaCmd);

//   String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//       .replaceAll(' ', '').toUpperCase();

//   print("CLEANED SENT HEX: $sentHex");

//   // Breakdown expectation:
//   // 20 -> Header
//   // 06 -> Length (3 + 3)
//   // 19 -> Sub-function
//   // 41 -> 'A'
//   // 42 -> 'B'
//   // 43 -> 'C'
//   // 0000 -> CRC (current mock result)
  
//   expect(sentHex.startsWith("200619414243"), isTrue, 
//     reason: "Packet should follow [20][Len][19][Data]");
// });
//     test('SetFota: Handles length calculation for longer strings', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN);
//       String fotaCmd = "UPDATE"; // 6 characters

//       await dongle.dongleSetFota(fotaCmd);

//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       // Length = 3 (fixed) + 6 (UPDATE) = 9 -> "09"
//       expect(sentHex.substring(2, 4), "09", reason: "Length byte should be 09");
//       expect(sentHex.contains("19"), isTrue, reason: "Should contain sub-function 19");
//     });

//     // --- GET WIFI MAC ID COMMAND TESTS ---

//     test('GetWifiMacId: Should parse the RESPONSE into AA:BB:CC format', () async {
//   // 1. Setup Mock Response (20 01 21 + 6 bytes of MAC + CRC)
//   // Let's pretend the MAC is 00:1A:2B:3C:4D:5E
//   mockController.mockResponse = Uint8List.fromList([
//     0x20, 0x01, 0x21, // Header & Sub-function
//     0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E, // The MAC Address bytes
//     0x30, 0x8B // Dummy CRC
//   ]);

//   // 2. Execute the call
//   final response = await dongleComm.getWifiMacId();

//   // 3. Parse the result (The logic you'll use in your UI)
//   if (response != null && response.length >= 9) {
//     String formattedMac = response
//         .sublist(3, 9) // Take just the 6 MAC bytes
//         .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
//         .join(':');

//     print("FORMATTED MAC: $formattedMac");
    
//     expect(formattedMac, "00:1A:2B:3C:4D:5E");
//   } else {
//     fail("Response was null or too short");
//   }
// });

// // --- UPDATE FIRMWARE COMMAND TESTS ---

//     test('updateFirmware: Correctly calculates length and prepends 0019', () async {
//       // 1. Setup
//       // URL "AABB" is 4 chars. (4 ~/ 2) + 2 = 4. 
//       // Length should be 04.
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN);
//       String mockUrl = "AABB"; 

//       // 2. Execute
//       await dongle.updateFirmware(mockUrl);

//       // 3. Verify outgoing bytes
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT UpdateFirmware Hex: $sentHex");

//       // BREAKDOWN:
//       // 20 (Header)
//       // 04 (Length: (4/2)+2)
//       // 0019 (Sub-function / Firmware command)
//       // AABB (URL)
//       // 00 (Suffix)
//       // XXXX (CRC)
      
//       expect(sentHex.startsWith("20040019AABB00"), isTrue, 
//         reason: "Packet structure should be 20 + Len + 0019 + URL + 00");
//     });

//     test('updateFirmware: Handles CRC padding for different URL lengths', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN);
      
//       // Long URL to check length byte
//       // "1122334455" (10 chars). (10 ~/ 2) + 2 = 7 -> "07"
//       await dongle.updateFirmware("1122334455");

//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       expect(sentHex.substring(2, 4), "07", reason: "Length byte should be 07");
//       expect(sentHex.contains("0019"), isTrue, reason: "Must contain 0019 sub-function");
//     });
//     test('canSetTxHeader: 11-Bit Protocol (Channel Mode)', () async {
//   // Use a known 11-bit protocol
//   final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
  
//   // TxHeader "07E0" (4 hex chars = 2 bytes)
//   await dongle.canSetTxHeader("07E0");

//   String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//       .replaceAll(' ', '').toUpperCase();

//   print("SENT 11-bit TX Header: $sentHex");

//   // Expect: 20 (Hdr) + 03 (Len) + 01 (Chan) + 04 (Sub) + 07E0 (Data)
//   expect(sentHex.startsWith("2003010407E0"), isTrue);
// });
// test('canSetTxHeader: 29-Bit Protocol (Standard Mode)', () async {
//   // Use a known 29-bit protocol
//   final dongle = DongleController("01", Protocol.ISO15765_500KB_29BIT_CAN, isChannel: false);
  
//   // TxHeader "18DB33F1" (8 hex chars = 4 bytes)
//   await dongle.canSetTxHeader("18DB33F1");

//   String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//       .replaceAll(' ', '').toUpperCase();

//   print("SENT 29-bit TX Header: $sentHex");

//   // Expect: 20 (Hdr) + 07 (Len) + 04 (Sub) + 18DB33F1 (Data)
//   expect(sentHex.startsWith("20070418DB33F1"), isTrue);
// });
// test('canSetTxHeader: K-Line Protocol (Channel Mode)', () async {
//   // Use a KWP protocol
//   final dongle = DongleController("01", Protocol.ISO14230_4KWP_FASTINIT_80, isChannel: true);
  
//   // TxHeader "C1" (2 hex chars = 1 byte)
//   await dongle.canSetTxHeader("C1");

//   String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//       .replaceAll(' ', '').toUpperCase();

//   print("SENT K-Line TX Header: $sentHex");

//   // Expect: 20 (Hdr) + 02 (Len) + 01 (Chan) + 04 (Sub) + C1 (Data)
//   expect(sentHex.startsWith("20020104C1"), isTrue);
// });
// // --- CAN GET TX HEADER COMMAND TESTS ---

//     test('canGetTxHeader: Channel Mode (isChannel: true) uses 2001 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // 2. Execute
//       await dongle.canGetTxHeader();
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT canGetTxHeader Hex (Channel): $sentHex");
      
//       // Expect: 2001 (Hdr) + 01 (Chan) + 05 (Sub-function)
//       expect(sentHex.startsWith("20010105"), isTrue, 
//         reason: "Channel mode should be 2001 + ChannelId + 05");
//     });

//     test('canGetTxHeader: Standard Mode (isChannel: false) uses 2003 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       // 2. Execute
//       await dongle.canGetTxHeader();
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT canGetTxHeader Hex (Standard): $sentHex");
      
//       // Expect: 2003 (Hdr) + 05 (Sub-function)
//       expect(sentHex.startsWith("200305"), isTrue, 
//         reason: "Standard mode should be 2003 + 05");
//     });

//     // --- CAN SET RX HEADER MASK COMMAND TESTS ---

//     test('canSetRxHeaderMask: 11-Bit Protocol (Channel Mode)', () async {
//       // 1. Setup - 11-bit mask is usually "07FF"
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // 2. Execute
//       await dongle.canSetRxHeaderMask("07FF");
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT 11-bit RX Mask (Channel): $sentHex");
      
//       // Expect: 2003 (Hdr) + 01 (Chan) + 06 (Sub) + 07FF (Mask)
//       expect(sentHex.startsWith("2003010607FF"), isTrue);
//     });

//     test('canSetRxHeaderMask: 29-Bit Protocol (Standard Mode)', () async {
//       // 1. Setup - 29-bit mask is usually "1FFFFFFF"
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_29BIT_CAN, isChannel: false);
      
//       // 2. Execute
//       await dongle.canSetRxHeaderMask("1FFFFFFF");
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT 29-bit RX Mask (Standard): $sentHex");
      
//       // Expect: 2007 (Hdr) + 06 (Sub) + 1FFFFFFF (Mask)
//       expect(sentHex.startsWith("2007061FFFFFFF"), isTrue);
//     });

//     test('canSetRxHeaderMask: K-Line Protocol (Channel Mode)', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO14230_4KWP_FASTINIT_80, isChannel: true);
      
//       // 2. Execute - K-Line mask might just be one byte "FF"
//       await dongle.canSetRxHeaderMask("FF");
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT K-Line RX Mask (Channel): $sentHex");
      
//       // Expect: 2002 (Hdr) + 01 (Chan) + 06 (Sub) + FF (Mask)
//       expect(sentHex.startsWith("20020106FF"), isTrue);
//     });
//     // --- CAN GET RX HEADER MASK COMMAND TESTS ---

//     test('canGetRxHeaderMask: Channel Mode (isChannel: true) uses 2001 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // 2. Execute
//       await dongle.canGetRxHeaderMask();
      
//       // 3. Verify outgoing bytes
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT canGetRxHeaderMask Hex (Channel): $sentHex");
      
//       // Expect: 2001 (Hdr) + 01 (Chan) + 07 (Sub-function)
//       expect(sentHex.startsWith("20010107"), isTrue, 
//         reason: "Channel mode should be 2001 + ChannelId + 07");
//     });

//     test('canGetRxHeaderMask: Standard Mode (isChannel: false) uses 2003 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       // 2. Execute
//       await dongle.canGetRxHeaderMask();
      
//       // 3. Verify outgoing bytes
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT canGetRxHeaderMask Hex (Standard): $sentHex");
      
//       // Expect: 2003 (Hdr) + 07 (Sub-function)
//       expect(sentHex.startsWith("200307"), isTrue, 
//         reason: "Standard mode should be 2003 + 07");
//     });
//     // --- CAN SET P1 MIN COMMAND TESTS ---

//     test('canSetP1Min: Channel Mode (isChannel: true) uses 2002 prefix', () async {
//       // 1. Setup - p1min "0A" (10ms)
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // 2. Execute
//       await dongle.canSetP1Min("0A");
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT SetP1Min Hex (Channel): $sentHex");
      
//       // Expect: 2002 (Hdr) + 01 (Chan) + 0C (Sub) + 0A (Value)
//       expect(sentHex.startsWith("2002010C0A"), isTrue);
//     });

//     test('canSetP1Min: Standard Mode (isChannel: false) uses 2004 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       // 2. Execute
//       await dongle.canSetP1Min("0A");
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT SetP1Min Hex (Standard): $sentHex");
      
//       // Expect: 2004 (Hdr) + 0C (Sub) + 0A (Value)
//       expect(sentHex.startsWith("20040C0A"), isTrue);
//     });
//     // --- CAN GET P1 MIN COMMAND TESTS ---

//     test('canGetP1Min: Channel Mode (isChannel: true) uses 2001 prefix', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
//       await dongle.canGetP1Min();

//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetP1Min Hex (Channel): $sentHex");
      
//       // Expect: 2001 (Hdr) + 01 (Chan) + 0D (Sub)
//       expect(sentHex.startsWith("2001010D"), isTrue);
//     });

//     test('canGetP1Min: Standard Mode (isChannel: false) uses 2003 prefix', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
//       await dongle.canGetP1Min();

//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetP1Min Hex (Standard): $sentHex");
      
//       // Expect: 2003 (Hdr) + 0D (Sub)
//       expect(sentHex.startsWith("20030D"), isTrue);
//     });

//     // --- CAN SET P2 MAX COMMAND TESTS ---

//     test('canSetP2Max: Channel Mode (isChannel: true) uses 2003 prefix', () async {
//       // 1. Setup - p2max "01F4" (500ms)
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // 2. Execute
//       await dongle.canSetP2Max("01F4");
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT SetP2Max Hex (Channel): $sentHex");
      
//       // Expect: 2003 (Hdr) + 01 (Chan) + 0E (Sub) + 01F4 (Value)
//       expect(sentHex.startsWith("2003010E01F4"), isTrue, 
//         reason: "Packet should be Header(2003) + Chan(01) + Sub(0E) + Value(01F4)");
//     });

//     test('canSetP2Max: Standard Mode (isChannel: false) uses 2005 prefix', () async {
//       // 1. Setup
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       // 2. Execute
//       await dongle.canSetP2Max("01F4");
      
//       // 3. Verify
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT SetP2Max Hex (Standard): $sentHex");
      
//       // Expect: 2005 (Hdr) + 0E (Sub) + 01F4 (Value)
//       expect(sentHex.startsWith("20050E01F4"), isTrue, 
//         reason: "Packet should be Header(2005) + Sub(0E) + Value(01F4)");
//     });

//     // --- CAN GET P2 MAX COMMAND TESTS ---

//     test('canGetP2Max: Channel Mode (isChannel: true) uses 2001 prefix', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
//       await dongle.canGetP2Max();

//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetP2Max Hex (Channel): $sentHex");
      
//       // Expect: 2001 (Hdr) + 01 (Chan) + 0F (Sub)
//       expect(sentHex.startsWith("2001010F"), isTrue);
//     });

//     test('canGetP2Max: Standard Mode (isChannel: false) uses 2003 prefix', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
//       await dongle.canGetP2Max();

//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       print("SENT GetP2Max Hex (Standard): $sentHex");
      
//       // Expect: 2003 (Hdr) + 0F (Sub)
//       expect(sentHex.startsWith("20030F"), isTrue);
//     });

//     test('canStartTp: RP1210 Path (Non-UART) uses bit-shifted SubCommandId', () async {
//   // 1. Setup
//   mockController.connectivity.value = Connectivity.rp1210Usb;
//   // TxArray[0] = 0x00 (0), TxArray[1] = 0x11 (17), TxArray[2] = 0x22 (34), TxArray[3] = 0x33 (51)
//  // dongleComm.txArray = Uint8List.fromList([0x00, 0x11, 0x22, 0x33, 0x44]);
  
//   // 2. Execute
//   await dongleComm.canStartTp();
  
//   final sentBytes = mockController.lastSentCommand!;
//   print("DEBUG SENT BYTES: $sentBytes");

//   // 3. Verify the specific payload slice
//   // Based on your log, the 4 bytes of TxArray start at index 13
//   Uint8List capturedPayload = sentBytes.sublist(13, 17);
  
//   expect(capturedPayload, [0, 17, 34, 51], 
//     reason: "The RP1210 packet should contain the TxArray bytes [0, 17, 34, 51] at the end");
    
//   // Also verify the Extended Address Flag (message[2]) which is at index 12
//   expect(sentBytes[12], 0, reason: "Extended address flag (index 12) should be 0");
// });

// test('setTesterPresent: Channel Mode uses Sub-ID 0C', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       // comm "02" (e.g., 20ms or specific TP type)
//       await dongle.setTesterPresent("02");
      
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       // Expect: 2002 (Hdr) + 01 (Chan) + 0C (Sub) + 02 (Data)
//       expect(sentHex.startsWith("2002010C02"), isTrue);
//     });
//     test('canStartPadding: Standard Mode uses 2004 prefix and Sub-ID 12', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
      
//       // paddingByte "AA"
//       await dongle.canStartPadding("AA");
      
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       // Expect: 2004 (Hdr) + 12 (Sub) + AA (Value)
//       expect(sentHex.startsWith("200412AA"), isTrue);
//     });

//     test('canStopPadding: Channel Mode uses 2001 prefix and Sub-ID 13', () async {
//       final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
      
//       await dongle.canStopPadding();
      
//       String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//           .replaceAll(' ', '').toUpperCase();

//       // Expect: 2001 (Hdr) + 01 (Chan) + 13 (Sub)
//       expect(sentHex.startsWith("20010113"), isTrue);
//     });
//     test('wifiWriteSSID: Channel Mode correctly calculates length and uses 1601', () async {
//   final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
  
//   // SSID "Guest" in hex is 5 bytes
//   String hexSsid = "4775657374"; 
//   await dongle.wifiWriteSSID(hexSsid);
  
//   String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//       .replaceAll(' ', '').toUpperCase();

//   // Logic: SSID length (5) + 3 = 8 (08)
//   // Format: 20 + 08 + 01 (Chan) + 1601 + 4775657374 + 00
//   expect(sentHex.startsWith("2008011601477565737400"), isTrue, 
//     reason: "Packet should follow the 20 + length + channel + ID structure");
// });
// test('wifiWritePW: Standard Mode correctly calculates length and uses 1701', () async {
//   final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
  
//   // Password "Pass123" in hex is 7 bytes
//   String hexPw = "50617373313233"; 
//   await dongle.wifiWritePW(hexPw);
  
//   String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//       .replaceAll(' ', '').toUpperCase();

//   // Logic: PW length (7) + 5 = 12 (0C)
//   // Format: 20 + 0C + 1701 + 50617373313233 + 00
//   expect(sentHex.startsWith("200C17015061737331323300"), isTrue);
// });

// group('canTxData Tests', () {
//       test('canTxData: correctly prefixes 40 and appends 4-char CRC', () async {
//         // 1. Setup - Data "010D" (Read Vehicle Speed)
//         final txData = "010D";
        
//         // 2. Execute
//         await dongleComm.canTxData(txData);
        
//         // 3. Verify
//         String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//             .replaceAll(' ', '').toUpperCase();

//         print("SENT canTxData Hex: $sentHex");
        
//         // Expect: 40 (Header) + 010D (Data) + XXXX (4-char CRC)
//         expect(sentHex.startsWith("40010D"), isTrue);
//         expect(sentHex.length, equals(10)); // 2(40) + 4(data) + 4(crc)
//       });
//     });
//  group('Wi-Fi Configuration Tests', () {
  
//   test('wifiWriteSSID: Channel Mode - 20 + Len + Chan + 1601 + SSID + 00', () async {
//     // 1. Setup: SSID "Home" (4 bytes -> "486F6D65")
//     final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: true);
//     String ssidHex = "486F6D65"; 
    
//     // 2. Execute
//     await dongle.wifiWriteSSID(ssidHex);
    
//     // 3. Verify
//     // Length calculation: (8 / 2) + 3 = 7 -> "07"
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toUpperCase();

//     // Format: 20 + 07 (Len) + 01 (Chan) + 1601 + 486F6D65 + 00 + [CRC]
//     expect(sentHex.startsWith("2007011601486F6D6500"), isTrue);
//   });

//   test('wifiWritePW: Standard Mode - 20 + Len + 1701 + PW + 00', () async {
//     // 1. Setup: PW "1234" (4 bytes -> "31323334")
//     final dongle = DongleController("01", Protocol.ISO15765_500KB_11BIT_CAN, isChannel: false);
//     String pwHex = "31323334";
    
//     // 2. Execute
//     await dongle.wifiWritePW(pwHex);
    
//     // 3. Verify
//     // Length calculation: (8 / 2) + 5 = 9 -> "09"
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toUpperCase();

//     // Format: 20 + 09 (Len) + 1701 + 31323334 + 00 + [CRC]
//     expect(sentHex.startsWith("200917013132333400"), isTrue);
//   });
// })
// ;
// group('ISO-TP Config Tests', () {
//   test('setBlkSeqCntr: Correctly builds 200408 prefix', () async {
//     // 1. Setup - Setting block length to 0x0F (15)
//     await dongleComm.setBlkSeqCntr("0F");
    
//     // 2. Verify
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toUpperCase();

//     // Expect: 20 (Hdr) + 04 (Len) + 08 (ID) + 0F (Value) + CRC
//     expect(sentHex.startsWith("2004080F"), isTrue);
//     expect(sentHex.length, 12); // 8 chars for command + 4 chars for CRC
//   });

//   test('getSepTime: Correctly builds 20030B prefix', () async {
//     await dongleComm.getSepTime();
    
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toUpperCase();

//     // Expect: 20 (Hdr) + 03 (Len) + 0B (ID) + CRC
//     expect(sentHex.startsWith("20030B"), isTrue);
//   });
// });
// test('CAN_TxRx: Triggers _handleReadAgainInternal when status is READAGAIN', () async {
//   int sendCommandCount = 0;
//   int readResponseCount = 0;

//   // 1. Setup Mock Behavior
//   mockController.onSendCommand = (bytes) {
//     sendCommandCount++;
//     // Return bytes that trigger decoded.$2 == "READAGAIN"
//     // (Ensure this byte matches your ResponseArrayDecoding logic)
//     return Uint8List.fromList([0x40, 0x01, 0x12, 0x00]); 
//   };

//   mockController.onReadResponse = () {
//     readResponseCount++;
//     // The hardware finally gets the response from the ECU
//     return Uint8List.fromList([0x40, 0x02, 0x01, 0x05, 0x00, 0x00]);
//   };

//   // 2. Execute
//   var result = await dongleComm.CAN_TxRx(2, "0105");

//   // 3. Verify
//   expect(sendCommandCount, 1, reason: "The command is sent only once.");
//   expect(readResponseCount, 1, reason: "readResponse() should be called because of READAGAIN.");
//   expect(result.ecuResponseStatus, isNot("READ_TIMEOUT"));
// });
// group('Wi-Fi Credential Retrieval - Verified CCITT Table', () {
  
//   test('canGetDefaultSSID: Verified full packet (22 00 -> 8b7d)', () async {
//     await dongleComm.canGetDefaultSSID();
    
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toLowerCase();

//     // Table CRC for [22, 00] is 0x7D8B -> Little Endian "8b7d"
//     expect(sentHex, "200422008b7d");
//   });

//   test('canGetUserSSID: Verified full packet (22 01 -> aa6d)', () async {
//     await dongleComm.canGetUserSSID();
    
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toLowerCase();

//     // Table CRC for [22, 01] is 0x6DAA -> Little Endian "aa6d"
//     expect(sentHex, "20042201aa6d");
//   });

//   test('canGetDefaultPassword: Verified full packet (23 00 -> ba4e)', () async {
//     await dongleComm.canGetDefaultPassword();
    
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toLowerCase();

//     // Table CRC for [23, 00] is 0x4EBA -> Little Endian "ba4e"
//     expect(sentHex, "20042300ba4e");
//   });

//   test('canGetDefaultPassword: Verified full packet (23 00 -> ba4e)', () async {
//     await dongleComm.canGetDefaultPassword();
    
//     String sentHex = CanConverters.bytesToHex(mockController.lastSentCommand!)
//         .replaceAll(' ', '').toLowerCase();

//     // Table CRC for [23, 00] is 0x4EBA -> Little Endian "ba4e"
//     // Format: 20 (Hdr) + 04 (Len) + 23 (Sub) + 00 (Idx) + ba4e (CRC)
//     expect(sentHex, "20042300ba4e");
//   });
// });
// group('RP1210 Command Logic Tests', () {

//   test('Verify ClientConnect (0x01) with Empty Message', () {
//     final message = Uint8List(0);
//     final result = dongleComm.getRP1210Command(DWCommandId.clientConnect, message);

//     // Total length = 4 (length) + 2 (clientId) + 4 (cmdId) + 0 (payload) = 10 bytes
//     // Hex representation: 00 00 00 0A (Length) | 00 00 (Client) | 00 00 00 01 (Cmd)
//     expect(result, isNotNull);
//     expect(result!.length, 10);
    
//     // Check Length Field (Bytes 0-3: Big Endian)
//     expect(result.sublist(0, 4), [0x00, 0x00, 0x00, 0x0A]);
    
//     // Check Client ID (Bytes 4-5)
//     expect(result.sublist(4, 6), [0x00, 0x00]);
    
//     // Check Command ID (Bytes 6-9: Big Endian)
//     expect(result.sublist(6, 10), [0x00, 0x00, 0x00, 0x01]);
//   });

//   test('Verify SendMessage (0x03) with Payload and Offset Accuracy', () {
//     final message = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
//     final result = dongleComm.getRP1210Command(DWCommandId.sendMessage, message);

//     // Total length = 10 (headers) + 3 (payload) = 13 bytes (Hex: 0x0D)
//     expect(result!.length, 13);
    
//     // Check Length Field
//     expect(result.sublist(0, 4), [0x00, 0x00, 0x00, 0x0D]);
    
//     // Check Command ID (DWCommandId.sendMessage is 0x03)
//     expect(result.sublist(6, 10), [0x00, 0x00, 0x00, 0x03]);
    
//     // Check Payload (Should start at index 10)
//     expect(result.sublist(10), [0xAA, 0xBB, 0xCC]);
//   });

//   test('Verify DoipSendMessage (0x09) with Big Endian Bit Shifting', () {
//     final message = Uint8List.fromList([0x01, 0x02]);
//     final result = dongleComm.getRP1210Command(DWCommandId.doipSendMessage, message);

//     // Verify the command ID part specifically
//     // DWCommandId.doipSendMessage is 0x09
//     expect(result!.sublist(6, 10), [0x00, 0x00, 0x00, 0x09]);
//   });
// });

// }