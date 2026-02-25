import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ap_dongle_comm/utils/dongleComm.dart';
import 'package:ap_dongle_comm/utils/enums/command_ids.dart';
import 'package:ap_dongle_comm/utils/enums/connectivity.dart';
import 'package:ap_dongle_comm/utils/helper/crc16_ccitt_kermit.dart';
import 'package:ap_dongle_comm/utils/helper/foreground_servie_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:convert/convert.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usb_serial/usb_serial.dart';


class CommController extends GetxController {
  var connectivity = Connectivity.none.obs;
   late DongleComm? dongleComm;
  var isConnected = false.obs;
UsbPort? _usbPort;
  StreamSubscription? _usbSub;
  Socket? _socket;
  StreamSubscription? _socketSub;
  SerialPort? _desktopPort;
  SerialPortReader? _desktopReader;
  final StreamController<Uint8List> _responseStream =
      StreamController.broadcast();
  final StreamController<bool> _connectionStream =
      StreamController.broadcast();

  Stream<Uint8List> get responses => _responseStream.stream;
  Stream<bool> get connectionUpdates => _connectionStream.stream;
  StreamSubscription? sub;

  Future<void> connectWifi({
  required String host,
  required int port,
}) async {
  try {
    await disconnect();

    _socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );

    print('SOCKET CONNECTED $host:$port');

    isConnected.value = true;
    connectivity.value = Connectivity.wiFi;
    _connectionStream.add(true);

    startForegroundService();

    _socketSub = _socket!.listen(
      _handleData,
      onError: (e) {
        print('Socket error: $e');
        _handleDisconnect();
        _reconnect(host, port);
      },
      onDone: () {
        print('Socket closed by dongle');
        _handleDisconnect();
      },
      cancelOnError: true,
    );
    Future.delayed(const Duration(milliseconds: 500), () async {
      print('Auto-initializing Dongle Protocol...');
      //await dongleComm!.dongleSetProtocol(protocolVersion: 02);
    });
  } on SocketException catch (e) {
    print('SocketException: $e');
    _handleDisconnect();
    rethrow;
  } catch (e) {
    _handleDisconnect();
    rethrow;
  }
}

  Future<void> connectUsb(UsbPort port) async {
  try {
    await disconnect();    
    _usbPort = port;
    isConnected.value = true;
    connectivity.value = Connectivity.usb;
    _connectionStream.add(true);
    if (_usbPort?.inputStream == null) {
      throw Exception("USB Input Stream is not available. Is the port open?");
    }
    _usbSub = _usbPort!.inputStream!.listen(
      (Uint8List data) {
        print("USB RX: ${bytesToHex(data)}");
        _handleData(data);
      },
      onError: (e) {
        print("USB Stream Error: $e");
        _handleDisconnect();
      },
      onDone: () {
        print("USB Device Disconnected");
        _handleDisconnect();
      },
    );    
    print("Mobile USB Connection established and listening.");
  } catch (e) {
    print("Failed to connect USB: $e");
    _handleDisconnect();
    rethrow;
  }
}

Future<void> connectDesktopUsb(String address, int baudRate) async {
  try {
    await disconnect();
    _desktopPort = SerialPort(address);

    if (!_desktopPort!.openReadWrite()) {
      final lastErr = SerialPort.lastError;
      throw Exception("OS Error: ${lastErr?.message ?? 'Unknown'} (Code: ${lastErr?.errorCode})");
    }
    final config = SerialPortConfig();
    config.baudRate = baudRate;
    config.bits = 8;
    config.stopBits = 1;
    config.parity = SerialPortParity.none;
    config.setFlowControl(SerialPortFlowControl.none);

    config.dtr = 1; 
    config.rts = 1;
    _desktopPort!.config = config;
    print("⏳ Stabilizing hardware...");
    await Future.delayed(const Duration(seconds: 1));
    _desktopPort!.flush();

    isConnected.value = true;
    connectivity.value = Connectivity.usb;
    _connectionStream.add(true);
    _desktopReader = SerialPortReader(_desktopPort!);
   _desktopReader!.stream.listen(
  (data) => _handleData(Uint8List.fromList(data)),
  onError: (e) {
    if (e.toString().contains("errno = 0")) {
      print("ℹ️ Ignored system notification (errno 0)");
      return; 
    }
    print("❌ Real Serial Error: $e");
    _handleDisconnect();
  },
  onDone: () => _handleDisconnect(),
);
    print("✅ Port $address configured and listening at $baudRate");
  } catch (e) {
    print("Error in connectDesktopUsb: $e");
    _handleDisconnect();
    rethrow;
  }
}

Future<void> disconnectVCI() async {
  try {
    await sub?.cancel();
    sub = null;
    if ([
      Connectivity.usb,
      Connectivity.rp1210Usb,
      Connectivity.canFdUsb,
      Connectivity.doipUsb
    ].contains(connectivity.value)) {

      if (_usbPort != null) {
        await _usbPort!.close();
        _usbPort = null;
      }

      if (_desktopPort != null) {
        _desktopPort!.dispose();
        _desktopPort = null;
      }
      
    } else {
      if (_socket != null) {
        await _socket!.flush();
        await _socket!.close();
        _socket = null;
      }
    }
    isConnected.value = false;
    print("VCI Disconnected successfully.");    
  } catch (e) {
    print("Error during disconnectVCI: $e");
  }
}

Uint8List wrapPacket(Uint8List payload, int headerByte, {int? channel}) {
  final builder = BytesBuilder();
  builder.addByte(headerByte);
  builder.addByte(payload.length);
  builder.addByte(channel!);
  builder.add(payload);
  List<int> crc = Crc16CcittKermit.computeChecksumBytes(payload);
  builder.add(crc);
  return builder.toBytes();
}


String formatHex(Uint8List bytes) {
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

Future<Uint8List?> sendCommand(Uint8List finalPacket, {Duration timeout = const Duration(seconds: 5)}) async {
  if (!isConnected.value) return null;

  final Completer<Uint8List> completer = Completer();
  final List<int> responseBuffer = []; 


  sub = responses.listen((data) {
    responseBuffer.addAll(data);
  });

  try {
    print("[SENDING] ${bytesToHex(finalPacket)}");
    if ([
      Connectivity.wiFi, 
      Connectivity.rp1210WiFi, 
      Connectivity.canFdWiFi, 
      Connectivity.doipWiFi
    ].contains(connectivity.value) && _socket != null) {
      
      _socket!.add(finalPacket);
      await _socket!.flush(); 
    } 
    else if ([
      Connectivity.usb, 
      Connectivity.rp1210Usb, 
      Connectivity.canFdUsb, 
      Connectivity.doipUsb
    ].contains(connectivity.value)) {

      if (_usbPort != null) {
        await _usbPort!.write(finalPacket);
      } 

      else if (_desktopPort != null) {
        _desktopPort!.write(finalPacket);
      } else {
        throw Exception("No USB or Desktop Port available");
      }
    } 
    return await completer.future.timeout(timeout);

  } catch (e) {
    if (responseBuffer.isNotEmpty) {
      final received = Uint8List.fromList(responseBuffer);
      print("[RECEIVED DYNAMIC] ${bytesToHex(received)}");
      return received;
    }

    return Uint8List.fromList("No Resp From Dongle".codeUnits);
  } finally {
    await sub!.cancel();
  }
}



void _handleData(Uint8List data) {
  // ignore: unused_local_variable
  String hexStr = bytesToHex(data);
  if (data.length > 2 && data[0] == 0x46 && data[1] == 0x57) {
    // ignore: unused_local_variable
    String decoded = String.fromCharCodes(data).trim();
  }

  if (isConnected.value) {
    _responseStream.add(data);
  }
}

 Future<void> disconnect() async {
    await _socketSub?.cancel();
    await _socket?.close();
    await _usbSub?.cancel();
    await _usbPort?.close();
    _desktopReader?.close();
    _desktopPort?.close();
    _desktopPort = null;
    _socket = null;
    _usbPort = null;
    isConnected.value = false;
    connectivity.value = Connectivity.none;
    _connectionStream.add(false);
  }

  void _handleDisconnect() {
    isConnected.value = false;
    connectivity.value = Connectivity.none;
    _connectionStream.add(false);
    FlutterForegroundTask.stopService();
  }

  // ---------------- RECONNECT ----------------
  Future<void> _reconnect(String host, int port) async {
    await disconnect();
    await Future.delayed(const Duration(seconds: 2));
    await connectWifi(host: host, port: port);
  }

  // ---------------- UTILS ----------------
  Uint8List hexToBytes(String hexStr) {
    hexStr = hexStr.replaceAll(' ', '');
    return Uint8List.fromList(hex.decode(hexStr));
  }

  String bytesToHex(Uint8List bytes) {
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' '); 
}


Future<void> clearBuffer() async {
  print("🧹 Draining RX Buffer (Waiting for silence)...");
  int totalDiscarded = 0;
  bool isNoiseFlowing = true;

  while (isNoiseFlowing) {
    try {
      Uint8List chunk = await _readExactBytes(1).timeout(
        const Duration(milliseconds: 300),
      );
      totalDiscarded += chunk.length;
    } on TimeoutException {
      isNoiseFlowing = false;
    } catch (e) {
      isNoiseFlowing = false;
    }
  }
  print("🧹 Drain complete. Discarded $totalDiscarded bytes of boot noise.");
}
  @override
  void onClose() {
    disconnect();
    _responseStream.close();
    _connectionStream.close();
    super.onClose();
  }

//  Future<Uint8List?> readData() async {
//   print("------Read Again Data------");
  
//   try {
//     if (connectivity == Connectivity.usb || 
//         connectivity == Connectivity.rp1210Usb ||
//         connectivity == Connectivity.canFdUsb || 
//         connectivity == Connectivity.doipUsb) {
      
      
//          return await getUsbResponse();
     
//     } 
//     else if (connectivity == Connectivity.wiFi || 
//              connectivity == Connectivity.rp1210WiFi ||
//              connectivity == Connectivity.canFdWiFi || 
//              connectivity == Connectivity.doipWiFi) {
      
//       return await getWifiResponse();
//     }   
//     // 3. Bluetooth Low Energy (BLE)
//     // else if (connectivity == Connectivity.ble) {
//     //   return await getBleResponse();
//     // }   
//   } catch (e) {
//     print("Error during ReadData: $e");
//     return null;
//   }
//   print("------END Read Again Data------");
//   return null;
// }


Future<Uint8List?> readData() async {
  print("------Read Again Data------");
  
  try {
    if (connectivity == Connectivity.usb || 
        connectivity == Connectivity.rp1210Usb ||
        connectivity == Connectivity.canFdUsb || 
        connectivity == Connectivity.doipUsb) {
      
      return await getUsbResponse();
     
    } 
    else if (connectivity == Connectivity.wiFi || 
             connectivity == Connectivity.rp1210WiFi ||
             connectivity == Connectivity.canFdWiFi || 
             connectivity == Connectivity.doipWiFi) {
      
      return await getWifiResponse();
    }   
    
    // If no connectivity matches, you might want a toast here
    _showToast("Unsupported connectivity type", isError: true);

  } catch (e) {
    print("Error during ReadData: $e");
    _showToast("Read Error: $e", isError: true);
    return null;
  }
  
  print("------END Read Again Data------");
  return null;
}

// Helper method to keep UI code clean
void _showToast(String message, {bool isError = false}) {
  Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.redAccent : Colors.black87,
      textColor: Colors.white,
      fontSize: 14.0
  );
}

  String _byteArrayToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(" ").toUpperCase();
  }

// Future<Uint8List> _readExactBytes(int length) async {
//   List<int> accumulated = [];
//   Completer<Uint8List> completer = Completer();
//   StreamSubscription? subscription;
//   subscription = _responseStream.stream.listen(
//     (data) {
//       accumulated.addAll(data);
//       if (accumulated.length >= length) {
//         if (!completer.isCompleted) {
//           completer.complete(Uint8List.fromList(accumulated.take(length).toList()));
//         }
//       }
//     },
//     onError: (e) {
//       if (!completer.isCompleted) completer.completeError(e);
//     },
//     cancelOnError: true,
//   );
//   return completer.future.timeout(
//     const Duration(seconds: 4), 
//     onTimeout: () {
//       subscription?.cancel();
//       print("⚠️ Timeout: Only received ${accumulated.length}/$length bytes.");
//       return Uint8List.fromList(accumulated);
//     },
//   ).whenComplete(() => subscription?.cancel());
// }

Future<Uint8List> _readExactBytes(int length) async {
  List<int> accumulated = [];
  Completer<Uint8List> completer = Completer();
  StreamSubscription? subscription;

  subscription = _responseStream.stream.listen(
    (data) {
      accumulated.addAll(data);
      if (accumulated.length >= length) {
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(accumulated.take(length).toList()));
        }
      }
    },
    onError: (e) {
      print("❌ Stream Error: $e");
      _showToast("Stream Error: $e", isError: true); // Added Error Toast
      if (!completer.isCompleted) completer.completeError(e);
    },
    cancelOnError: true,
  );

  return completer.future.timeout(
    const Duration(seconds: 4),
    onTimeout: () {
      subscription?.cancel();
      String errorMsg = "Timeout: Got ${accumulated.length} of $length bytes";
      print("⚠️ $errorMsg");
      
      // Notify the user about the partial data/timeout
      _showToast(errorMsg, isError: true); 
      
      return Uint8List.fromList(accumulated);
    },
  ).whenComplete(() => subscription?.cancel());
}



Future<Uint8List> getWifiResponse() async {
  if (connectivity.value == Connectivity.wiFi) {
    try {
      print("WiFi Communication : ---------INSIDE READ DATA -----------${DateTime.now()}");
      final Uint8List trgtlen = await _readExactBytes(2);
      print("WiFi Communication : ---------Target Length Response Received = ${_byteArrayToHex(trgtlen)} -----------");
      final int msglen = ((trgtlen[0] & 0x0F) << 8) + trgtlen[1];
      final Uint8List retArray = Uint8List(msglen + 5);
      retArray.setRange(0, 2, trgtlen);
      final Uint8List remData = await _readExactBytes(msglen + 3);
      retArray.setRange(2, 2 + remData.length, remData);

      print("WiFi Communication : ---------Response Received = ${_byteArrayToHex(retArray)} -----------");
      return retArray;
    } catch (e) {
      print("Exception @GetWifiResponse : $e");
      return Uint8List.fromList("No Resp From Dongle".codeUnits);
    }
  } else {
    try {
      Uint8List rawResp = await getRP1210WifiResponse();
      var (bool readAgain, Uint8List? decodedResp) = decodeRP1210Message(rawResp);
      while (readAgain == true) {
        rawResp = await getRP1210WifiResponse();
        final result = decodeRP1210Message(rawResp);
        readAgain = result.$1;
        decodedResp = result.$2;
      }

      return decodedResp ?? Uint8List.fromList("No Resp From Dongle".codeUnits);
    } catch (e) {
      print("Exception @GetWifiResponse (RP1210 Path): $e");
      return Uint8List.fromList("No Resp From Dongle".codeUnits);
    }
  }
}

(bool readAgain, Uint8List? resp) decodeRP1210Message(Uint8List response) {
  try {
    if (response.length < 10) return (false, null);
    int cmdIdValue = response[9];
    DWCommandId dWCommandId = DWCommandId.fromValue(cmdIdValue); 


    switch (dWCommandId) {
      case DWCommandId.clientConnect:
      case DWCommandId.clientDisconnect:
      case DWCommandId.readVersion:
      case DWCommandId.sendCommand:
        return (false, response.sublist(10));

      case DWCommandId.sendMessage:
      case DWCommandId.doipSendMessage: 
        return (true, null);

      case DWCommandId.readMessage:
        if (response[14] == 1 && response[21] == 0) {
          return (true, null);
        }
        return (false, response.sublist(21));

      case DWCommandId.doipReadMessage:
        int doipTypeValue = (response[12] << 8) | response[13];
        DoipMsgType doipMsgType = DoipMsgType.fromValue(doipTypeValue);

        if (doipMsgType == DoipMsgType.routineActivationReq ||
            doipMsgType == DoipMsgType.diagnosticMsgAck) {
          return (true, null);
        } else if (doipMsgType == DoipMsgType.routineActivationResp) {
          return (false, response.sublist(10));
        } else if (doipMsgType == DoipMsgType.diagnosticMsgNack ||
                   doipMsgType == DoipMsgType.diagnosticMsg) {
          return (false, response.sublist(22));
        }
        break;

      default:
        break;
    }
  } catch (e) {
    print("Exception @DecodeRP1210Message : $e");
  }
  return (false, null);
}

// (bool readAgain, Uint8List? data) decodeRP1210Message(Uint8List response) {
//   try {
//     if (response.isEmpty) return (true, null); // still trigger read again for safety

//     // Safe check for length
//     int cmdIdValue = (response.length > 9) ? response[9] : 0;
//     DWCommandId dWCommandId = DWCommandId.fromValue(cmdIdValue);

//     Uint8List actualData;

//     switch (dWCommandId) {
//       case DWCommandId.clientConnect:
//       case DWCommandId.clientDisconnect:
//       case DWCommandId.readVersion:
//       case DWCommandId.sendCommand:
//         actualData = response.length > 10 ? response.sublist(10) : Uint8List(0);
//         return (false, actualData.isNotEmpty ? actualData : null);

//       case DWCommandId.sendMessage:
//       case DWCommandId.doipSendMessage:
//         return (true, null);

//       case DWCommandId.readMessage:
//         if (response.length > 21) {
//           if (response[14] == 1 && response[21] == 0) {
//             return (true, null); // still expect more
//           }
//           return (false, response.sublist(21));
//         }
//         return (false, null);

//       case DWCommandId.doipReadMessage:
//         if (response.length > 13) {
//           int doipTypeValue = (response[12] << 8) | response[13];
//           DoipMsgType doipMsgType = DoipMsgType.fromValue(doipTypeValue);

//           // Only trigger READAGAIN for activationReq or Ack
//           if (doipMsgType == DoipMsgType.routineActivationReq ||
//               doipMsgType == DoipMsgType.diagnosticMsgAck) {
//             return (true, null);
//           }

//           // Other types -> return actual payload
//           if (doipMsgType == DoipMsgType.routineActivationResp ||
//               doipMsgType == DoipMsgType.diagnosticMsgNack ||
//               doipMsgType == DoipMsgType.diagnosticMsg) {
//             return (false, response.sublist(10));
//           }
//         }
//         return (false, response.length > 10 ? response.sublist(10) : null);

//       default:
//         // Unknown command: do not trigger read again if response has data
//         if (response.length > 10) {
//           return (false, response.sublist(10));
//         }
//         _showToast("Unknown Command ID: 0x${cmdIdValue.toRadixString(16)}");
//         break;
//     }
//   } catch (e) {
//     print("Exception @DecodeRP1210Message : $e");
//     _showToast("Decoding Error: $e", isError: true);
//   }

//   return (false, null);
// }


 Future<Uint8List> getRP1210WifiResponse() async {
  try {
    print("WiFi Communication: --------- INSIDE RP1210 READ DATA ---------");

    // Step 1: Read 4-byte header
    Uint8List header = await _readExactBytes(4);
    
    // CRITICAL FIX: Verify we actually got 4 bytes
    if (header.length < 4) {
      print("WiFi Communication: ! Timeout or Connection Closed. Received ${header.length}/4 bytes.");
      return Uint8List.fromList("No Resp From Dongle".codeUnits);
    }
    print("WiFi Communication: --------- Target Length Header Received = ${header.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}");
    int msgLen = (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];
    if (msgLen <= 4 || msgLen > 10000) { 
      print("WiFi Communication: ! Invalid Message Length: $msgLen");
      return Uint8List.fromList("No Resp From Dongle".codeUnits);
    }

    Uint8List retArray = Uint8List(msgLen);
    retArray.setRange(0, 4, header);
    Uint8List remaining = await _readExactBytes(msgLen - 4);
    
    if (remaining.length < (msgLen - 4)) {
       print("WiFi Communication: ! Partial Data Received. Expected ${msgLen - 4}, got ${remaining.length}");
       return Uint8List.fromList("No Resp From Dongle".codeUnits);
    }

    retArray.setRange(4, retArray.length, remaining);

    print("WiFi Communication: --------- Response Received = ${retArray.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}");
    return retArray;
    
  } catch (e) {
    print("Exception @getRP1210WifiResponse: $e");
    return Uint8List.fromList("No Resp From Dongle".codeUnits);
  }
}

// Future<Uint8List> getUsbResponse() async {
//   try {
//     // --- BRANCH 1: STANDARD USB (Standard CAN/System) ---
//     if (connectivity.value == Connectivity.usb) {
//       print("USB Communication : --------- Inside Read Data -----------${DateTime.now()}");

//       // Read the 2-byte header to find the length
//       final Uint8List trgtlen = await _readExactBytes(2);
      
//       // C# Logic: Calculate length (Byte0 & 0x0F) << 8 + Byte1
//       final int msglen = ((trgtlen[0] & 0x0F) << 8) + trgtlen[1];

//       // Prepare full buffer: 2 bytes header + msglen + 3 bytes (CRC/Trailing)
//       final Uint8List retArray = Uint8List(msglen + 5);
//       retArray.setRange(0, 2, trgtlen);

//       // Read the remaining payload
//       final Uint8List remData = await _readExactBytes(msglen + 3);
//       retArray.setRange(2, 2 + remData.length, remData);

//       print("USB Communication : --------- Response Received = ${_byteArrayToHex(retArray)} -----------");
//       return retArray;

//     } 
//     else {
//       Uint8List resp = await getRP1210UsbResponse();
//       if (resp.length >= 4 && !listEquals(resp, Uint8List.fromList("No Resp From Dongle".codeUnits))) {
//         // Extract 4-byte length: (resp[0] << 24) | (resp[1] << 16) | (resp[2] << 8) | resp[3]
//         int msgLen = ByteData.sublistView(resp).getUint32(0, Endian.big);

//         if (resp.length > msgLen) {
//           // Slice: In C# resp[msgLen..] - takes everything AFTER the first full message
//           resp = resp.sublist(msgLen);
//         } 
//         else if (resp.length < msgLen) {
//           // Stitch: Read more bytes if the buffer was fragmented
//           Uint8List remResp = await getRP1210UsbResponse();
          
//           if (!listEquals(remResp, Uint8List.fromList("No Resp From Dongle".codeUnits))) {
//             final builder = BytesBuilder();
//             builder.add(resp);
//             builder.add(remResp);
//             resp = builder.toBytes();

//             // Re-check: If combined data is now longer than the header indicates
//             if (resp.length > msgLen) {
//               resp = resp.sublist(msgLen);
//             }
//           }
//         }
//       }
//       var result = decodeRP1210Message(resp);
//       bool readAgain = result.$1;
//       Uint8List? decodedResp = result.$2;
//       int safetyCounter = 0;
//       while (readAgain == true && safetyCounter < 10) {
//         resp = await getRP1210UsbResponse();
//         if (resp.length >= 4) {
//           int mLen = ByteData.sublistView(resp).getUint32(0, Endian.big);
//           if (resp.length > mLen) resp = resp.sublist(mLen);
//         }

//         var nextResult = decodeRP1210Message(resp);
//         readAgain = nextResult.$1;
//         decodedResp = nextResult.$2;
        
//         safetyCounter++;
//       }

//       return decodedResp ?? Uint8List.fromList("No Resp From Dongle".codeUnits);
//     }
//   } catch (e) {
//     print("Exception @GetUSBResponse: $e");
//     return Uint8List.fromList("No Resp From Dongle".codeUnits);
//   }
// }

Future<Uint8List> getUsbResponse() async {
  try {
    // --- BRANCH 1: STANDARD USB ---
    if (connectivity.value == Connectivity.usb) {
      print("USB Communication : --------- Inside Read Data -----------${DateTime.now()}");

      final Uint8List trgtlen = await _readExactBytes(2);
      final int msglen = ((trgtlen[0] & 0x0F) << 8) + trgtlen[1];

      final Uint8List retArray = Uint8List(msglen + 5);
      retArray.setRange(0, 2, trgtlen);

      final Uint8List remData = await _readExactBytes(msglen + 3);
      retArray.setRange(2, 2 + remData.length, remData);

      print("USB Communication : --------- Response Received = ${_byteArrayToHex(retArray)} -----------");
      return retArray;

    } 
    // --- BRANCH 2: RP1210 / DOIP USB ---
    else {
      Uint8List resp = await getRP1210UsbResponse();
      
      if (resp.length >= 4 && !listEquals(resp, Uint8List.fromList("No Resp From Dongle".codeUnits))) {
        int msgLen = ByteData.sublistView(resp).getUint32(0, Endian.big);

        if (resp.length > msgLen) {
          resp = resp.sublist(msgLen);
        } 
        else if (resp.length < msgLen) {
          // Toast for fragmentation - helps debug slow USB serial links
          _showToast("Fragmented packet detected, stitching...", isError: false);
          
          Uint8List remResp = await getRP1210UsbResponse();
          if (!listEquals(remResp, Uint8List.fromList("No Resp From Dongle".codeUnits))) {
            final builder = BytesBuilder();
            builder.add(resp);
            builder.add(remResp);
            resp = builder.toBytes();

            if (resp.length > msgLen) {
              resp = resp.sublist(msgLen);
            }
          }
        }
      }

      var result = decodeRP1210Message(resp);
      bool readAgain = result.$1;
      Uint8List? decodedResp = result.$2;
      
      int safetyCounter = 0;
      while (readAgain == true && safetyCounter < 10) {
        resp = await getRP1210UsbResponse();
        if (resp.length >= 4) {
          int mLen = ByteData.sublistView(resp).getUint32(0, Endian.big);
          if (resp.length > mLen) resp = resp.sublist(mLen);
        }

        var nextResult = decodeRP1210Message(resp);
        readAgain = nextResult.$1;
        decodedResp = nextResult.$2;
        
        safetyCounter++;
        
        // If we are looping many times, warn the user
        if (safetyCounter > 5) {
          _showToast("Extended handshake in progress ($safetyCounter/10)...");
        }
      }

      if (safetyCounter >= 10) {
        _showToast("Communication timeout: Loop limit reached", isError: true);
      }

      return decodedResp ?? Uint8List.fromList("No Resp From Dongle".codeUnits);
    }
  } catch (e) {
    print("Exception @GetUSBResponse: $e");
    _showToast("USB Communication Error: $e", isError: true);
    return Uint8List.fromList("No Resp From Dongle".codeUnits);
  }
}

// Future<Uint8List> getRP1210UsbResponse() async {
//   try {
//     print("USB Communication : --------- Inside Read Data -----------${DateTime.now()}");

//     Uint8List trgtlen = await _readExactBytes(4); 
//     if (trgtlen.length < 4) {
//       print("USB Communication : ! Timeout or partial header received: ${trgtlen.length} bytes");
//       return Uint8List(0); 
//     }

//     print("USB Communication : ---------Target Length Header Received = ${_byteArrayToHex(trgtlen)} -----------");
//     int msgLen = (trgtlen[0] << 24) | 
//                  (trgtlen[1] << 16) | 
//                  (trgtlen[2] << 8)  | 
//                   trgtlen[3];
//     if (msgLen <= 4 || msgLen > 4096) { 
//       return trgtlen; 
//     }
//     Uint8List retArray = Uint8List(msgLen);
//     retArray.setRange(0, 4, trgtlen);

//     Uint8List remData = await _readExactBytes(msgLen - 4);
    
//     if (remData.length < (msgLen - 4)) {
//       print("USB Communication : ! Incomplete payload. Expected ${msgLen - 4}, got ${remData.length}");
//       return Uint8List(0);
//     }

//     retArray.setRange(4, msgLen, remData);
    
//     print("USB Communication : ---------Response Received = ${_byteArrayToHex(retArray)} -----------");
//     return retArray;

//   } catch (e) {
//     print("Exception @GetRP1210UsbResponse : $e");
//     return Uint8List(0); 
//   }
// }

Future<Uint8List> getRP1210UsbResponse() async {
  try {
    print("USB Communication : --------- Inside Read Data -----------${DateTime.now()}");

    // 1. Read the 4-byte RP1210 length header
    Uint8List trgtlen = await _readExactBytes(4); 
    if (trgtlen.length < 4) {
      String error = "Header Timeout: Received ${trgtlen.length}/4 bytes";
      print("USB Communication : ! $error");
      _showToast(error, isError: true); 
      return Uint8List(0); 
    }

    print("USB Communication : ---------Target Length Header Received = ${_byteArrayToHex(trgtlen)} -----------");
    
    // Calculate expected length (Big Endian)
    int msgLen = (trgtlen[0] << 24) | 
                 (trgtlen[1] << 16) | 
                 (trgtlen[2] << 8)  | 
                  trgtlen[3];

    // 2. Validate length
    if (msgLen <= 4 || msgLen > 4096) { 
      // This usually means the stream is out of sync or noise was picked up
      _showToast("Invalid RP1210 Length: $msgLen bytes", isError: true);
      return trgtlen; 
    }

    // 3. Read the payload
    Uint8List retArray = Uint8List(msgLen);
    retArray.setRange(0, 4, trgtlen);

    Uint8List remData = await _readExactBytes(msgLen - 4);
    
    if (remData.length < (msgLen - 4)) {
      String error = "Incomplete Payload: Expected ${msgLen - 4}, got ${remData.length}";
      print("USB Communication : ! $error");
      _showToast(error, isError: true);
      return Uint8List(0);
    }

    retArray.setRange(4, msgLen, remData);
    
    print("USB Communication : ---------Response Received = ${_byteArrayToHex(retArray)} -----------");
    return retArray;

  } catch (e) {
    print("Exception @GetRP1210UsbResponse : $e");
    _showToast("RP1210 Read Exception: $e", isError: true);
    return Uint8List(0); 
  }
}




}