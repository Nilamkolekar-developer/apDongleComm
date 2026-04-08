// ignore: file_names
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ap_dongle_comm/utils/dongleComm.dart';
import 'package:ap_dongle_comm/utils/enums/command_ids.dart';
import 'package:ap_dongle_comm/utils/enums/connectivity.dart';
import 'package:ap_dongle_comm/utils/helper/crc16_ccitt_kermit.dart';
import 'package:ap_dongle_comm/utils/helper/foreground_servie_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:get/get.dart';
import 'package:convert/convert.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usb_serial/usb_serial.dart';

class CommController extends GetxController {
  var connectivity = Connectivity.none.obs;
  SerialPort? serialPort;
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
  // StreamController<bool>? _connvectionStream;
  // ignore: prefer_final_fields
  StreamController<bool> _connectionStream = StreamController.broadcast();

  Stream<Uint8List> get responses => _responseStream.stream;
  Stream<bool> get connectionUpdates => _connectionStream.stream;
  StreamSubscription? sub;

  Future<void> connectWifi({
    required String host,
    required int port,
    required Connectivity selectedType, // ✅ Add this parameter
  }) async {
    try {
      print(
        "🌐 [connectWifi] Attempting $selectedType connection to $host:$port...",
      );
      await disconnect();

      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(minutes: 1),
      );

      print('✅ SOCKET CONNECTED $host:$port');

      isConnected.value = true;

      // ✅ Set the dynamic connectivity value
      connectivity.value = selectedType;

      _connectionStream.add(true);
      startForegroundService();

      _socketSub = _socket!.listen(
        (data) {
          // Use the same handleData logic we used for USB
          _handleData(data);
        },
        // onError: (e) {
        //   print('❌ Socket error: $e');
        //   _handleDisconnect();
        //   //_reconnect(host, port, selectedType);
        // },
        // onDone: () {
        //   print('⚠️ Socket closed by dongle');
        //   _handleDisconnect();
        // },
        cancelOnError: true,
      );

      // Give the WiFi bridge a moment to stabilize
      // await Future.delayed(const Duration(milliseconds: 500));
      _buffer.clear();

      print('🚀 $selectedType Ready over WiFi');
    } on SocketException catch (e) {
      print('🔥 SocketException: $e');
      _handleDisconnect();
      rethrow;
    } catch (e) {
      print('🔥 Connection Error: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  Future<void> connectUsb(
    UsbPort port,
    int baudRate,
    Connectivity selectedType,
  ) async {
    try {
      print(
        "🔌 Starting Mobile USB connection ($selectedType) at $baudRate baud...",
      );
      await disconnect();

      _usbPort = port;

      bool openResult = await _usbPort!.open();
      if (!openResult) throw Exception("Could not open USB port");

      await _usbPort!.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // Hardware wake-up
      await _usbPort!.setDTR(false);
      await _usbPort!.setRTS(false);
      await Future.delayed(const Duration(milliseconds: 100));
      await _usbPort!.setDTR(true);
      await _usbPort!.setRTS(true);

      _usbSub = _usbPort!.inputStream!.listen(
        (Uint8List data) {
          if (data.isNotEmpty) {
            print("📥 RAW USB ($selectedType): ${bytesToHex(data)}");
            _handleData(data);
          }
        },
        onError: (e) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
        cancelOnError: true,
      );

      print("⏳ Stabilizing $selectedType hardware...");
      await Future.delayed(const Duration(milliseconds: 2500));

      _buffer.clear();

      isConnected.value = true;

      // ✅ DYNAMIC CONNECTIVITY ASSIGNMENT
      // This ensures sendCommand() and getUSBResponse() know which logic to use
      if (selectedType == Connectivity.rp1210Usb) {
        connectivity.value = Connectivity.rp1210Usb;
      } else if (selectedType == Connectivity.canFdUsb) {
        connectivity.value = Connectivity.canFdUsb;
      } else if (selectedType == Connectivity.doipUsb) {
        connectivity.value = Connectivity.doipUsb;
      } else {
        connectivity.value = Connectivity.usb;
      }

      _connectionStream.add(true);
      print("✅ Mobile USB Ready: Connected as ${connectivity.value}");
    } catch (e) {
      print("🔥 USB Connection Failed ($selectedType): $e");
      _handleDisconnect();
    }
  }

  Future<void> connectDesktopUsb(
    String address,
    int baudRate,
    Connectivity selectedType,
  ) async {
    try {
      await disconnect();
      _desktopPort = SerialPort(address);

      if (!_desktopPort!.openReadWrite()) {
        final lastErr = SerialPort.lastError;
        throw Exception("OS Error: ${lastErr?.message ?? 'Unknown'}");
      }

      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;

      // 🔥 CRITICAL: Force raw mode (no Windows processing)
      config.setFlowControl(SerialPortFlowControl.none);
      config.dtr = 1;
      config.rts = 1;

      _desktopPort!.config = config;

      print("⏳ Stabilizing hardware...");
      await Future.delayed(const Duration(milliseconds: 1500));
      _desktopPort!.flush();

      isConnected.value = true;
      // connectivity.value = Connectivity.usb;
      if (selectedType == Connectivity.rp1210Usb) {
        connectivity.value = Connectivity.rp1210Usb;
      } else if (selectedType == Connectivity.canFdUsb) {
        connectivity.value = Connectivity.canFdUsb;
      } else if (selectedType == Connectivity.doipUsb) {
        connectivity.value = Connectivity.doipUsb;
      } else {
        connectivity.value = Connectivity.usb;
      }
      _connectionStream.add(true);

      // 🚀 FIX: Don't use SerialPortReader. Use manual fast polling.
      _startManualDesktopRead();

      print("✅ Windows Port $address configured and listening at $baudRate");
    } catch (e) {
      print("Error in connectDesktopUsb: $e");
      _handleDisconnect();
      rethrow;
    }
  }

  // High-speed polling loop
  void _startManualDesktopRead() async {
    while (isConnected.value && _desktopPort != null) {
      try {
        // Check hardware buffer
        int bytesToRead = _desktopPort!.bytesAvailable;
        if (bytesToRead > 0) {
          final data = _desktopPort!.read(bytesToRead);
          if (data.isNotEmpty) {
            _handleData(Uint8List.fromList(data));
          }
        }
      } catch (e) {
        print("❌ Serial Loop Error: $e");
        _handleDisconnect();
        break;
      }
      // 1ms is essential for ECU timing on Windows
      await Future.delayed(const Duration(milliseconds: 1));
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
        Connectivity.doipUsb,
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

  Uint8List wrapPacket1(Uint8List payload, int headerByte, {int? channel}) {
    final builder = BytesBuilder();
    builder.addByte(headerByte);
    builder.addByte(payload.length);
    builder.addByte(channel!);
    builder.add(payload);
    List<int> crc = Crc16CcittKermit.computeChecksumBytes(payload);
    builder.add(crc);
    return builder.toBytes();
  }

  Uint8List wrapPacket(Uint8List payload, int headerByte, {int? channel}) {
    final builder = BytesBuilder();

    builder.addByte(headerByte); // header
    builder.addByte(payload.length); // length
    builder.addByte(channel!); // channel
    builder.add(payload); // payload
    Uint8List packetSoFar = builder.toBytes();
    List<int> crc = Crc16CcittKermit.computeChecksumBytes(packetSoFar);

    builder.add(crc);
    return builder.toBytes();
  }

  String formatHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  Future<Uint8List?> sendCommand(
    Uint8List finalPacket, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (connectivity.value == Connectivity.none) {
      return null;
    }

    try {
      print("[SENDING HEX] ${bytesToHex(finalPacket)}");

      // ── WiFi Section ─────────────────────────────────────────
      if ([
        Connectivity.wiFi,
        Connectivity.canFdWiFi,
        Connectivity.rp1210WiFi,
        Connectivity.doipWiFi,
      ].contains(connectivity.value)) {
        final socket = _socket;
        if (socket == null) return null;

        socket.add(finalPacket);
        await socket.flush();

        print("📥 Waiting for WiFi response...");
        return await getWifiResponse();
      }
      // ── USB Section ─────────────────────────────────────────
      else if ([
        Connectivity.usb,
        Connectivity.canFdUsb,
        Connectivity.rp1210Usb,
        Connectivity.doipUsb,
      ].contains(connectivity.value)) {
        if (_usbPort != null) {
          // ✅ Mobile USB
          await _usbPort!.write(finalPacket);

          // 🔥 IMPORTANT: delay AFTER write
          await Future.delayed(const Duration(milliseconds: 50));
        } else if (_desktopPort != null) {
          // ✅ Windows
          _desktopPort!.write(finalPacket);
        } else {
          return Uint8List.fromList(utf8.encode('No Resp From Dongle'));
        }

        print("📥 Waiting for USB response...");
        return await getUSBResponse();
      } else {
        print("[ERROR] Unknown connectivity type");
        return null;
      }
    } catch (e) {
      print("[EXCEPTION in sendCommand] $e");
      return Uint8List.fromList(utf8.encode('No Resp From Dongle'));
    }
  }

  void _handleData(Uint8List data) {
    if (data.isEmpty) return;

    // 🔍 Debug BEFORE adding
    print("🧠 BEFORE ADD Buffer: ${bytesToHex(Uint8List.fromList(_buffer))}");

    // ✅ Add incoming data
    _buffer.addAll(data);

    // 🔍 Debug AFTER adding
    print("📥 RAW RX: ${bytesToHex(data)}");
    print("📦 Buffer Size: ${_buffer.length}");

    // Optional stream (safe)
    if (isConnected.value) {
      _responseStream.add(data);
    }
  }

  Future<void> disconnect() async {
    try {
      print("🔌 Starting full disconnect...");

      /// 🔥 SOCKET CLEANUP
      await _socketSub?.cancel();
      _socketSub = null;

      await _socket?.close();
      _socket = null;

      /// 🔥 USB CLEANUP
      if (_usbSub != null) {
        await _usbSub!.cancel();
        _usbSub = null;
        print("🧹 USB stream cancelled");
      }

      if (_usbPort != null) {
        await _usbPort!.close();
        _usbPort = null;
        print("🔌 USB port closed");
      }

      /// 🔥 DESKTOP CLEANUP
      _desktopReader?.close();
      _desktopReader = null;

      _desktopPort?.close();
      _desktopPort = null;

      /// 🔥 RESET STATE
      isConnected.value = false;
      connectivity.value = Connectivity.none;
      _connectionStream.add(false);

      /// 🔥 VERY IMPORTANT DELAY
      await Future.delayed(const Duration(milliseconds: 500));

      print("✅ Full disconnect completed");
    } catch (e) {
      print("🔥 Disconnect error: $e");
    }
  }

  void _handleDisconnect() async {
    print("⚠️ Handling unexpected disconnect...");

    await disconnect(); // 🔥 THIS IS THE FIX

    FlutterForegroundTask.stopService();
  }

  // ---------------- RECONNECT ----------------

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
    print("🧹 [clearBuffer] Draining RX Buffer...");

    if (_buffer.isEmpty) {
      print("      -> Buffer already empty. Ready.");
      return;
    }

    // Record what we are throwing away for debugging
    int discardedCount = _buffer.length;
    String discardedHex = bytesToHex(Uint8List.fromList(_buffer));

    // 🔥 THE FIX: Instant wipe.
    // No loops, no _readExactBytes(1), no timeouts.
    _buffer.clear();

    print(
      "🧹 [clearBuffer] Drain complete. Discarded $discardedCount bytes: [$discardedHex]",
    );
  }

  Future<Uint8List?> readData() async {
    print("------Read Again Data------");

    try {
      Uint8List? result;

      if ([
        Connectivity.usb,
        Connectivity.rp1210Usb,
        Connectivity.canFdUsb,
        Connectivity.doipUsb,
      ].contains(connectivity.value)) {
        result = await getUSBResponse();
      } else if ([
        Connectivity.wiFi,
        Connectivity.rp1210WiFi,
        Connectivity.canFdWiFi,
        Connectivity.doipWiFi,
      ].contains(connectivity.value)) {
        result = await getWifiResponse();
      } else {
        // _showToast("Unsupported connectivity type", isError: true);
        return null;
      }

      print("------END Read Again Data------");
      return result;
    } catch (e) {
      print("Error during ReadData: $e");
      //_showToast("Read Error: $e", isError: true);
      return null;
    }
  }

  List<int> _buffer = [];

  Future<Uint8List> _readExactBytes(int length, {int timeoutSec = 1}) async {
    final DateTime startTime = DateTime.now();

    while (_buffer.length < length) {
      await Future.delayed(const Duration(milliseconds: 1));

      if (DateTime.now().difference(startTime).inSeconds > timeoutSec) {
        print(
          "❌ TIMEOUT: Needed $length, Have ${_buffer.length}. Clearing Buffer.",
        );
        _buffer.clear(); // 🔥 Clear on timeout to reset synchronization
        return Uint8List(0);
      }
    }

    final result = Uint8List.fromList(_buffer.sublist(0, length));
    _buffer.removeRange(0, length);

    // 🔍 Add this print to track exactly what is being taken
    print("✅ [_readExactBytes] Extracted $length bytes: ${bytesToHex(result)}");

    return result;
  }

  Future<Uint8List> getWifiResponse() async {
    try {
      if (connectivity.value == Connectivity.wiFi) {
        while (true) {
          print("WiFi Communication : ---------INSIDE READ DATA -----------");

          // Step 1: Read 2 bytes (Header)
          Uint8List trgtlen = await _readExactBytes(2, timeoutSec: 5);
          if (trgtlen.isEmpty) {
            return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
          }

          // Step 2: Calculate msglen (Matches C# logic)
          int msglen = ((trgtlen[0] & 0x0F) << 8) + trgtlen[1];

          // Step 3: Read remaining body (msglen + 3)
          // (C# uses msglen + 5 total, we read 2 then msglen + 3)
          Uint8List remData = await _readExactBytes(msglen + 3, timeoutSec: 5);
          if (remData.isEmpty) {
            return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
          }

          final builder = BytesBuilder();
          builder.add(trgtlen);
          builder.add(remData);
          Uint8List retArray = builder.toBytes();

          print(
            "WiFi Communication : ---------Response Received = ${bytesToHex(retArray)} -----------",
          );

          // 🔥 THE FIX: NRC 78 Handling (ECU Pending)
          // If we see 7F [Service] 78, we loop again just like C# "ReadAgain = true"
          if (retArray.length >= 6 &&
              retArray[3] == 0x7F &&
              retArray[5] == 0x78) {
            print("⚠️ NRC 0x78 Detected: ECU Busy. Reading again...");
            continue;
          }

          return retArray;
        }
      }
      // ── CASE 2: RP1210 WiFi ──
      else {
        Uint8List resp = await getRP1210WifiResponse();
        var decodeResult = decodeRP1210Message(resp);

        // This matches your C# 'while (decodeResult.ReadAgain == true)'
        while (decodeResult.$1 == true) {
          print("🔄 RP1210 ReadAgain triggered...");
          resp = await getRP1210WifiResponse();
          decodeResult = decodeRP1210Message(resp);
        }

        return decodeResult.$2 ??
            Uint8List.fromList(utf8.encode("No Resp From Dongle"));
      }
    } catch (e) {
      print("Exception @getWifiResponse : $e");
      return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
    }
  }

  Future<Uint8List> getWifiResponse1() async {
    try {
      // ── CASE 1: Standard WiFi / CAN2X Path ──
      if (connectivity.value == Connectivity.wiFi) {
        print("📡 [DEBUG] Standard WiFi Read Started");

        // 1. Read Header (2 bytes: Command ID and Status/Length)
        Uint8List header = await _readExactBytes(2, timeoutSec: 5);
        if (header.isEmpty) return Uint8List.fromList(utf8.encode("No Resp"));

        // 2. Identify the length
        // In your successful CAN2X logs:
        // 20 01 ... -> 01 is status, but usually implies 4 bytes follow (CRC + Suffix)
        // 20 03 ... -> 03 is length of data payload
        int dataLen = header[1];

        // The Standard packet suffix is usually 3 bytes (2 bytes CRC + 1 byte 0xF0)
        int remaining = dataLen + 3;

        // 3. Read Body
        Uint8List body = await _readExactBytes(remaining, timeoutSec: 5);
        if (body.isEmpty) return Uint8List.fromList(utf8.encode("No Resp"));

        final builder = BytesBuilder();
        builder.add(header);
        builder.add(body);
        Uint8List fullPacket = builder.toBytes();

        print("✅ [DEBUG] Standard Response: ${bytesToHex(fullPacket)}");

        // Handle NRC 78 (Busy)
        if (fullPacket.length >= 6 &&
            fullPacket[3] == 0x7F &&
            fullPacket[5] == 0x78) {
          print("⚠️ ECU Busy (78), Retrying...");
          return await getWifiResponse();
        }

        return fullPacket;
      }
      // ── CASE 2: RP1210 WiFi Path ──
      else {
        // Keep your working RP1210 logic here
        Uint8List resp = await getRP1210WifiResponse();
        var decodeResult = decodeRP1210Message(resp);

        while (decodeResult.$1 == true) {
          print("🔄 RP1210 ReadAgain triggered...");
          resp = await getRP1210WifiResponse();
          decodeResult = decodeRP1210Message(resp);
        }
        return decodeResult.$2 ?? Uint8List.fromList(utf8.encode("No Resp"));
      }
    } catch (e) {
      print("❌ Exception @getWifiResponse: $e");
      return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
    }
  }

  (bool readAgain, Uint8List? resp) decodeRP1210Message(Uint8List response) {
    try {
      // 1. Safety check: RP1210 headers + CmdID require at least 10 bytes
      if (response.length < 10) {
        debugPrint("⚠️ Response too short to decode: ${bytesToHex(response)}");
        return (false, null);
      }

      final int cmdId = response[9];
      final DWCommandId dwCommandId = DWCommandId.fromValue(cmdId);

      // 2. Parse the 4-byte Return Code (Val)
      // In your hex: [10][11][12][13] is 00 00 00 00
      int val = 0;
      if (response.length >= 14) {
        val =
            (response[10] << 24) |
            (response[11] << 16) |
            (response[12] << 8) |
            response[13];
      }

      switch (dwCommandId) {
        case DWCommandId.clientConnect:
          debugPrint("📡 RP1210 Connect Result Code: $val (0 = Success)");
          // Returns the 4-byte result code [0,0,0,0]
          return (false, Uint8List.sublistView(response, 10, 14));

        case DWCommandId.clientDisconnect:
        case DWCommandId.readVersion:
        case DWCommandId.sendCommand:
          return (false, Uint8List.sublistView(response, 10));

        case DWCommandId.sendMessage:
          // Echo or ACK for send - usually tells the app to wait for the actual response
          return (true, null);

        case DWCommandId.readMessage:
          // Ensure indices exist before accessing
          if (response.length < 22) return (false, response);

          bool isProtocolMessage = response[14] == 1;
          bool hasData = response[21] == 1;

          if (isProtocolMessage && !hasData) {
            return (true, null); // Just a protocol ACK, read again for data
          }

          // Return the actual payload starting at index 21
          return (false, Uint8List.sublistView(response, 21));

        case DWCommandId.doipSendMessage:
          return (true, null);

        case DWCommandId.doipReadMessage:
          if (response.length < 14) return (false, null);

          final int typeValue = (response[12] << 8) | response[13];
          final DoipMsgType doipMsgType = DoipMsgType.fromValue(typeValue);

          if (doipMsgType == DoipMsgType.routineActivationReq ||
              doipMsgType == DoipMsgType.diagnosticMsgAck) {
            return (true, null);
          } else if (doipMsgType == DoipMsgType.routineActivationResp) {
            return (false, Uint8List.sublistView(response, 10));
          } else {
            // Standard Diagnostic message or Nack
            return (false, Uint8List.sublistView(response, 22));
          }

        default:
          debugPrint("❓ Unknown Command ID: ${cmdId.toRadixString(16)}");
          // Return raw response instead of null to prevent "No Resp" errors
          return (false, response);
      }
    } catch (ex, stackTrace) {
      debugPrint('❌ Exception @decodeRP1210Message : $ex\n$stackTrace');
      return (false, null);
    }
  }

  Future<Uint8List> getRP1210WifiResponse() async {
    try {
      print("WiFi Communication : ---------INSIDE READ DATA -----------");

      // STEP 1: Read exactly 4 bytes for the RP1210 length header
      // This matches: byte[] RetArray = new byte[4];
      Uint8List header = await _readExactBytes(4, timeoutSec: 10);

      if (header.length < 4) {
        print("WiFi Communication : ! Header Timeout or Connection Closed.");
        return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
      }

      print(
        "WiFi Communication : ---------Target Length Response Received = ${bytesToHex(header)} -----------",
      );

      // STEP 2: Parse length (Big Endian)
      // Matches: int msgLen = (RetArray[0] << 24) | (RetArray[1] << 16) | (RetArray[2] << 8) | RetArray[3];
      int msgLen =
          (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];

      // Guard against invalid lengths
      if (msgLen <= 4 || msgLen > 10000) {
        print("WiFi Communication : ! Invalid Message Length: $msgLen");
        return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
      }

      // STEP 3: Read the remaining bytes (msgLen - 4)
      // Matches: readByte = await Stream.ReadAsync(RetArray, 4, RetArray.Length - 4...);
      int remainingLen = msgLen - 4;
      Uint8List remaining = await _readExactBytes(remainingLen, timeoutSec: 10);

      if (remaining.length < remainingLen) {
        print("WiFi Communication : ! Partial Body Received.");
        return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
      }

      // STEP 4: Combine Header and Body
      final fullBuffer = BytesBuilder();
      fullBuffer.add(header);
      fullBuffer.add(remaining);

      Uint8List retArray = fullBuffer.toBytes();

      print(
        "WiFi Communication : ---------Response Received = ${bytesToHex(retArray)} -----------",
      );

      return retArray;
    } catch (e) {
      print("Exception @getRP1210WifiResponse : $e");
      return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
    }
  }

  // Future<Uint8List?> getUSBResponse() async {
  //   if (connectivity.value == Connectivity.usb) {
  //     try {
  //       debugPrint('USB Communication : ---------INSIDE READ DATA -----------');

  //       final DateTime startTime = DateTime.now();

  //       // 1. Wait for data to arrive
  //       while (_buffer.isEmpty) {
  //         await Future.delayed(const Duration(milliseconds: 10));

  //         if (DateTime.now().difference(startTime).inSeconds > 5) {
  //           debugPrint('Exception @getUSBResponse : Timeout - Buffer Empty');

  //           return Uint8List.fromList(utf8.encode('No Resp From Dongle'));
  //         }
  //       }

  //       // 2. Small delay to allow fragmented packets to finish arriving
  //       // (Essential for Android USB serial buffers)
  //       await Future.delayed(const Duration(milliseconds: 50));

  //       // 3. ✅ FIX: Extract AND Clear the buffer
  //       final Uint8List data = Uint8List.fromList(_buffer);
  //       _buffer.clear();

  //       debugPrint(
  //         'USB Communication : ---------Response Received = ${byteArrayToString(data)}',
  //       );

  //       return data;
  //     } catch (ex) {
  //       debugPrint('Exception @getUSBResponse : $ex');

  //       return Uint8List.fromList(utf8.encode('No Resp From Dongle'));
  //     }
  //   } else {
  //     // RP1210 Logic
  //     // getRP1210USBResponse already has internal toasts via _readExactBytes
  //     Uint8List resp = await getRP1210USBResponse();
  //     var decodeResult = decodeRP1210Message(resp);

  //     while (decodeResult.$1 == true) {
  //       debugPrint("🔄 RP1210 ReadAgain triggered...");
  //       resp = await getRP1210USBResponse();
  //       decodeResult = decodeRP1210Message(resp);
  //     }

  //     return decodeResult.$2;
  //   }
  // }
  Future<Uint8List?> getUSBResponse() async {
    if (connectivity.value == Connectivity.usb) {
      try {
        debugPrint('USB Communication : ---------INSIDE READ DATA -----------');

        // 1. Read the first 2 bytes (Target Length Header)
        // This matches: uint bytesToRead = await dataReader.LoadAsync(2);
        Uint8List trgtlen = await _readExactBytes(2, timeoutSec: 5);

        if (trgtlen.isEmpty) {
          return Uint8List.fromList(utf8.encode('No Resp From Dongle'));
        }

        debugPrint(
          'USB Communication : ---------Target Length Response Received = ${byteArrayToString(trgtlen)}',
        );

        // 2. Calculate message length (Mirroring C# bitwise logic)
        // uint msglen = (uint)(((trgtlen[0] & 0x0F) << 8) + trgtlen[1]);
        int msglen = ((trgtlen[0] & 0x0F) << 8) + trgtlen[1];

        // 3. Read the rest of the response
        // C# reads msglen + 3 more bytes (Data + CRC + Suffix)
        Uint8List remData = await _readExactBytes(msglen + 3, timeoutSec: 5);

        if (remData.isEmpty) {
          return Uint8List.fromList(utf8.encode('No Resp From Dongle'));
        }

        // 4. Combine into final array (Matches C# RetArray = new byte[msglen + 5])
        final builder = BytesBuilder();
        builder.add(trgtlen);
        builder.add(remData);
        final retArray = builder.toBytes();

        debugPrint(
          'USB Communication : ---------Response Received = ${byteArrayToString(retArray)}',
        );
        return retArray;
      } catch (ex) {
        debugPrint('Exception @getUSBResponse : $ex');
        return Uint8List.fromList(utf8.encode('No Resp From Dongle'));
      }
    } else {
      // RP1210 Logic (Keep as is, it's working)
      Uint8List resp = await getRP1210USBResponse();
      var decodeResult = decodeRP1210Message(resp);

      while (decodeResult.$1 == true) {
        debugPrint("🔄 RP1210 ReadAgain triggered...");
        resp = await getRP1210USBResponse();
        decodeResult = decodeRP1210Message(resp);
      }
      return decodeResult.$2;
    }
  }

  String byteArrayToString(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  Future<Uint8List> getRP1210USBResponse() async {
    try {
      // 1. Read Header (4 bytes)
      Uint8List header = await _readExactBytes(4, timeoutSec: 5);
      if (header.length < 4) return Uint8List(0);

      // 2. Parse Length
      int msgLen =
          (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];

      // 3. Read Body
      int bodyLen = msgLen - 4;
      Uint8List body = await _readExactBytes(bodyLen, timeoutSec: 3);

      // 🔥 THE FIX: Atomic Concatenation using BytesBuilder
      final builder = BytesBuilder();
      builder.add(header);
      builder.add(body);

      final fullPacket = builder.toBytes();

      // 🔍 Debug: If this still shows double 0E, then _readExactBytes
      // is picking up the header twice from the hardware buffer.
      print("✅ Reassembled: ${bytesToHex(fullPacket)}");
      return fullPacket;
    } catch (e) {
      print("Error: $e");
      return Uint8List(0);
    }
  }
}
