import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:ap_dongle_comm/utils/dongleComm.dart';
import 'package:ap_dongle_comm/utils/enums/command_ids.dart';
import 'package:ap_dongle_comm/utils/enums/connectivity.dart';
import 'package:ap_dongle_comm/utils/helper/crc16_ccitt_kermit.dart';
import 'package:ap_dongle_comm/utils/helper/foreground_servie_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  Future<void> connectWifi({required String host, required int port}) async {
    try {
      await disconnect();

      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );

      print('SOCKET CONNECTED $host:$port');

      isConnected.value = true;
      connectivity.value = Connectivity.rp1210WiFi;
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
      print("🔌 Starting USB connection...");

      // Fluttertoast.showToast(msg: "Connecting to USB...");
      if (_usbSub != null) {
        await _usbSub!.cancel();
        _usbSub = null;
        print("🧹 Old listener removed");
      }

      _usbPort = port;

      /// 🔥 WAIT FOR PORT READY
      await Future.delayed(Duration(milliseconds: 300));

      if (_usbPort?.inputStream == null) {
        throw Exception("USB Input Stream not ready");
      }

      isConnected.value = true;
      connectivity.value = Connectivity.rp1210Usb;
      _connectionStream.add(true);

      print("📡 Starting listener...");

      _usbSub = _usbPort!.inputStream!.listen(
        (Uint8List data) {
          print("📥 USB RX: ${bytesToHex(data)}");
          _handleData(data);
        },
        onError: (e) {
          print("❌ USB Stream Error: $e");
          // Fluttertoast.showToast(msg: "USB Stream Error");
          _handleDisconnect();
        },
        onDone: () {
          print("⚠️ USB Disconnected");
          //Fluttertoast.showToast(msg: "USB Disconnected");
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      print("✅ USB Listener Started");
    } catch (e) {
      print("🔥 USB Connection Failed: $e");
      //Fluttertoast.showToast(msg: "USB Connection Failed");

      _handleDisconnect();
    }
  }

  Future<void> connectDesktopUsb(String address, int baudRate) async {
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
      await Future.delayed(const Duration(milliseconds: 500));
      _desktopPort!.flush();

      isConnected.value = true;
      connectivity.value = Connectivity.rp1210Usb;
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
    if (connectivity.value == Connectivity.none) return null;

    try {
      print("[SENDING HEX] ${bytesToHex(finalPacket)}");

      // ── SEND ─────────────────────────────────────────
      if ([
        Connectivity.wiFi,
        Connectivity.canFdWiFi,
        Connectivity.rp1210WiFi,
        Connectivity.doipWiFi,
      ].contains(connectivity.value)) {
        if (_socket == null) throw Exception("Socket is null");

        _socket!.add(finalPacket);
        await _socket!.flush();

        // 🔥 ADD THIS (WiFi read)
        print("📥 Waiting for WiFi response...");
        return await getWifiResponse();
      } else if ([
        Connectivity.usb,
        Connectivity.canFdUsb,
        Connectivity.rp1210Usb,
        Connectivity.doipUsb,
      ].contains(connectivity.value)) {
        if (_usbPort != null) {
          await _usbPort!.write(finalPacket);
        } else if (_desktopPort != null) {
          _desktopPort!.write(finalPacket);
        } else {
          throw Exception("No USB or Desktop Port available");
        }

        // 🔥 ADD THIS (USB read)
        print("📥 Waiting for USB response...");
        return await getUSBResponse();
      } else {
        print("[ERROR] Unknown connectivity type: ${connectivity.value}");
        return null;
      }
    } catch (e) {
      print("[EXCEPTION in sendCommand] $e");
      return Uint8List.fromList("No Resp From Dongle".codeUnits);
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

    Fluttertoast.showToast(msg: "Device Disconnected");
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
        Uint8List chunk = await _readExactBytes(
          1,
        ).timeout(const Duration(milliseconds: 300));
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
        _showToast("Unsupported connectivity type", isError: true);
        return null;
      }

      print("------END Read Again Data------");
      return result;
    } catch (e) {
      print("Error during ReadData: $e");
      _showToast("Read Error: $e", isError: true);
      return null;
    }
  }

  // Helper method to keep UI code clean
  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.redAccent : Colors.black87,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  String _byteArrayToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(" ")
        .toUpperCase();
  }

  List<int> _buffer = [];

  Future<Uint8List> _readExactBytes(int length, {int timeoutSec = 5}) async {
    final completer = Completer<Uint8List>();

    // Helper to extract and clear
    void tryComplete() {
      if (_buffer.length >= length && !completer.isCompleted) {
        final result = Uint8List.fromList(_buffer.sublist(0, length));
        _buffer = _buffer.sublist(length);
        completer.complete(result);
      }
    }

    tryComplete();

    if (!completer.isCompleted) {
      StreamSubscription? sub;
      sub = _responseStream.stream.listen((data) {
        _buffer.addAll(data);
        tryComplete();
        if (completer.isCompleted) sub?.cancel();
      });

      return completer.future.timeout(
        Duration(seconds: timeoutSec),
        onTimeout: () {
          sub?.cancel();
          // 🔥 FIX: If we timeout, we MUST clear the buffer.
          // Otherwise, the 4-byte header of the NEXT message will be out of alignment.
          print(
            "⚠️ Read Timeout: Clearing out-of-sync buffer (${_buffer.length} bytes discarded)",
          );
          _buffer.clear();
          return Uint8List(0);
        },
      );
    }
    return completer.future;
  }

  Future<Uint8List> getWifiResponse() async {
    try {
      // ── CASE 1: Standard WiFi (trgtlen[2] logic) ───────────────────
      if (connectivity.value == Connectivity.wiFi) {
        print("WiFi Communication : ---------INSIDE READ DATA -----------");

        // Read 2 bytes for header
        Uint8List trgtlen = await _readExactBytes(2);
        print(
          "WiFi Communication : ---------Target Length Response Received = ${bytesToHex(trgtlen)} -----------",
        );

        // Calculate msglen from header
        int msglen = ((trgtlen[0] & 0x0F) << 8) + trgtlen[1];

        // Prepare full response array (msglen + 5)
        // Read remaining body (msglen + 3)
        Uint8List remData = await _readExactBytes(msglen + 3);

        final builder = BytesBuilder();
        builder.add(trgtlen);
        builder.add(remData);

        Uint8List retArray = builder.toBytes();
        print(
          "WiFi Communication : ---------Response Received = ${bytesToHex(retArray)} -----------",
        );

        return retArray;
      }
      // ── CASE 2: RP1210 / Other (The 'else' block) ──────────────────
      else {
        // var resp = await GetRP1210WifiResponse();
        Uint8List resp = await getRP1210WifiResponse();

        // var decodeResult = DecodeRP1210Message(resp);
        var decodeResult = decodeRP1210Message(resp);

        // while (decodeResult.ReadAgain == true)
        while (decodeResult.$1 == true) {
          // In Dart, result.$1 is ReadAgain
          // resp = await GetRP1210WifiResponse();
          resp = await getRP1210WifiResponse();

          // decodeResult = DecodeRP1210Message(resp);
          decodeResult = decodeRP1210Message(resp);
        }

        // return decodeResult.Resp; (Result.$2 is the payload)
        return decodeResult.$2 ?? Uint8List(0);
      }
    } catch (e) {
      print("Exception @getWifiResponse : $e");
      return Uint8List.fromList(utf8.encode("No Resp From Dongle"));
    }
  }

  String _byteArrayToString(Uint8List arr) {
    return arr.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  (bool readAgain, Uint8List? resp) decodeRP1210Message(Uint8List response) {
    try {
      // Basic safety check for minimum RP1210 packet size
      if (response.length < 10) return (false, null);

      int cmdId = response[9];
      // Mapping the byte to our Dart Enum
      DWCommandId dWCommandId = DWCommandId.values[cmdId];

      // matches: int val = (response[10] << 24) | ...
      // Note: We don't always use 'val', but it's here to match your logic
      int val =
          (response[10] << 24) |
          (response[11] << 16) |
          (response[12] << 8) |
          response[13];

      switch (dWCommandId) {
        case DWCommandId.clientConnect:
        case DWCommandId.clientDisconnect:
        case DWCommandId.readVersion:
        case DWCommandId.sendCommand:
          // matches: response[10..]
          return (false, response.sublist(10));

        case DWCommandId.sendMessage:
          return (true, null);

        case DWCommandId.readMessage:
          // matches: if (response[14] == 1 && response[21] == 0)
          if (response[14] == 1 && response[21] == 0) {
            return (true, null);
          }
          if (response[14] == 1 && response[21] == 1) {
            return (false, response.sublist(21));
          } else if (response[14] == 0) {
            return (false, response.sublist(21));
          }
          break;

        case DWCommandId.doipSendMessage:
          return (true, null);

        case DWCommandId.doipReadMessage:
          // matches: (response[12] << 8) | response[13]
          int typeVal = (response[12] << 8) | response[13];
          DoipMsgType doipMsgType = DoipMsgType.values[typeVal];

          if (doipMsgType == DoipMsgType.routineActivationReq ||
              doipMsgType == DoipMsgType.diagnosticMsgAck) {
            return (true, null);
          } else if (doipMsgType == DoipMsgType.routineActivationResp) {
            return (false, response.sublist(10));
          } else if (doipMsgType == DoipMsgType.diagnosticMsgNack) {
            return (false, response.sublist(22));
          } else if (doipMsgType == DoipMsgType.diagnosticMsg) {
            return (false, response.sublist(22));
          }
          break;

        default:
          break;
      }
    } catch (e, st) {
      print("Exception @decodeRP1210Message : $e\n$st");
    }
    return (false, null);
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

  Future<Uint8List> getUSBResponse() async {
    try {
      // --- BRANCH 1: STANDARD USB ---
      if (connectivity.value == Connectivity.usb) {
        print("------Read USB Data (Standard USB)------ ${DateTime.now()}");

        List<int> buffer = [];
        final completer = Completer<Uint8List>();
        StreamSubscription? usbReadSub; // ✅ renamed — no shadowing

        usbReadSub = responses.listen(
          (Uint8List chunk) {
            if (chunk.isEmpty || completer.isCompleted) return;

            buffer.addAll(chunk);
            print(
              "📥 [USB CHUNK] ${chunk.length} bytes, total=${buffer.length} | ${_byteArrayToHex(chunk)}",
            );

            if (buffer.length < 2) return;

            int msglen = ((buffer[0] & 0x0F) << 8) + buffer[1];

            // ✅ Validate msglen — prevent hang on noise
            if (msglen > 512) {
              print(
                "❌ Invalid msglen=$msglen — possible noise. Buffer: ${_byteArrayToHex(Uint8List.fromList(buffer))}",
              );
              usbReadSub?.cancel();
              completer.complete(
                Uint8List.fromList("No Resp From Dongle".codeUnits),
              );
              return;
            }

            int totalExpected = msglen + 5;
            print(
              "📏 msglen=$msglen totalExpected=$totalExpected current=${buffer.length}",
            );

            if (buffer.length >= totalExpected) {
              usbReadSub?.cancel();
              completer.complete(
                Uint8List.fromList(buffer.sublist(0, totalExpected)),
              );
            }
          },
          onError: (e) {
            print("❌ USB stream error: $e");
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () {
            // ✅ Handle disconnect mid-read
            print("⚠️ USB stream closed mid-read");
            if (!completer.isCompleted) {
              completer.complete(
                buffer.isNotEmpty
                    ? Uint8List.fromList(buffer)
                    : Uint8List.fromList("No Resp From Dongle".codeUnits),
              );
            }
          },
        );

        return await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            usbReadSub?.cancel();
            print(
              "⏰ USB timeout. Got ${buffer.length} bytes: ${_byteArrayToHex(Uint8List.fromList(buffer))}",
            );
            return buffer.isNotEmpty
                ? Uint8List.fromList(buffer)
                : Uint8List.fromList("No Resp From Dongle".codeUnits);
          },
        );
      }
      // --- BRANCH 2: RP1210 / DOIP USB --- (unchanged)
      else {
        Uint8List resp = await getRP1210UsbResponse();
        var result = decodeRP1210Message(resp);
        bool readAgain = result.$1;
        Uint8List? decodedResp = result.$2;

        int safetyCounter = 0;
        while (readAgain && safetyCounter < 10) {
          resp = await getRP1210UsbResponse();
          result = decodeRP1210Message(resp);
          readAgain = result.$1;
          decodedResp = result.$2;
          safetyCounter++;
          if (safetyCounter > 5) {
            _showToast("Extended handshake in progress ($safetyCounter/10)...");
          }
        }

        if (safetyCounter >= 10) {
          _showToast(
            "Communication timeout: Loop limit reached",
            isError: true,
          );
        }

        return decodedResp ??
            Uint8List.fromList("No Resp From Dongle".codeUnits);
      }
    } catch (e) {
      print("❌ Exception @getUsbResponse: $e");
      _showToast("USB Communication Error: $e", isError: true);
      return Uint8List.fromList("No Resp From Dongle".codeUnits);
    }
  }

  Future<Uint8List> getRP1210UsbResponse() async {
    try {
      print(
        "USB Communication : --------- Inside Read Data -----------${DateTime.now()}",
      );

      // 1. Read the 4-byte RP1210 length header
      Uint8List trgtlen = await _readExactBytes(2);
      if (trgtlen.length < 4) {
        String error = "Header Timeout: Received ${trgtlen.length}/4 bytes";
        print("USB Communication : ! $error");
        // _showToast(error, isError: true);
        return Uint8List(0);
      }

      print(
        "USB Communication : ---------Target Length Header Received = ${_byteArrayToHex(trgtlen)} -----------",
      );

      // Calculate expected length (Big Endian)
      int msgLen =
          (trgtlen[0] << 24) |
          (trgtlen[1] << 16) |
          (trgtlen[2] << 8) |
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

      Uint8List remData = await _readExactBytes(2);

      if (remData.length < (msgLen - 4)) {
        String error =
            "Incomplete Payload: Expected ${msgLen - 4}, got ${remData.length}";
        print("USB Communication : ! $error");
        //  _showToast(error, isError: true);
        return Uint8List(0);
      }

      retArray.setRange(4, msgLen, remData);

      print(
        "USB Communication : ---------Response Received = ${_byteArrayToHex(retArray)} -----------",
      );
      return retArray;
    } catch (e) {
      print("Exception @GetRP1210UsbResponse : $e");
      //   _showToast("RP1210 Read Exception: $e", isError: true);
      return Uint8List(0);
    }
  }
}
