import 'dart:convert';
import 'dart:typed_data';
import 'package:ap_dongle_comm/utils/commController.dart';
import 'package:ap_dongle_comm/utils/enums/command_ids.dart';
import 'package:ap_dongle_comm/utils/enums/connectivity.dart';
import 'package:ap_dongle_comm/utils/enums/protocol.dart';
import 'package:ap_dongle_comm/utils/helper/crc16_ccitt_kermit.dart';
import 'package:ap_dongle_comm/utils/helper/responseArrayDecoding.dart';
import 'package:ap_dongle_comm/utils/model/responseArrayStatusModel.dart';
import 'package:ap_dongle_comm/utils/model/sessionLogModel.dart';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DongleComm {
  CommController? comm;
  bool isChannel;
  String? channelId;
  List<SessionLogsModel> logs = []; // nullable, could be null
  DongleComm({this.comm, required this.isChannel, this.channelId});

  Future<Uint8List?> securityAccess() async {
    String command;

    if (isChannel) {
      command = '500A${channelId}47568AFE56214E238000FFC3';
    } else {
      command = '500C47568AFE56214E238000FFC3';
    }
    print("📤 Security Command String: $command");
    final bytes = comm!.hexToBytes(command);

    print("📤 Security Command Bytes Length: ${bytes.length}");
    print(
      "📤 Security Command HEX: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
    );

    print("➡️ Sending command to device...");
    // Send the command
    final response = await comm!.sendCommand(bytes);

    // Debug: show response in FlutterToast
    if (response != null) {
      String hexResponse = response
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      print("Security Access Response (hex): $hexResponse");

      Fluttertoast.showToast(
        msg: "Security Access Response: $hexResponse",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
    } else {
      print("Security Access Response is null");
      Fluttertoast.showToast(
        msg: "Security Access Response is null",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
    }

    return response;
  }

  Future<Uint8List?> getWifiMacId() async {
    try {
      print("------Start_Get_Mac_Id------");

      String commandHex;
      int crcByteIndex;

      if (isChannel) {
        commandHex = "2001${channelId}21";
        crcByteIndex = 3;
      } else {
        commandHex = "200321";
        crcByteIndex = 2;
      }
      Uint8List commandBytes = hexToBytes(commandHex);
      List<int> crcBytes = Crc16CcittKermit.computeChecksumBytes([
        commandBytes[crcByteIndex],
      ]);
      Uint8List fullCommand = Uint8List(commandBytes.length + crcBytes.length);
      fullCommand.setRange(0, commandBytes.length, commandBytes);
      fullCommand.setRange(commandBytes.length, fullCommand.length, crcBytes);

      print("[SENDING] ${bytesToHex(fullCommand)}");
      final response = await comm!.sendCommand(fullCommand);
      print(
        "[RAW MAC RESPONSE] ${response != null ? bytesToHex(response) : 'null'}",
      );

      return response;
    } catch (e) {
      print("❌ [GetWifiMacId] ERROR: $e");
      return null;
    }
  }

  Uint8List hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    if (hex.length % 2 != 0) hex = '0' + hex;
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  Future<Uint8List?> getFirmwareVersion() async {
    try {
      print("------Dongle_GetFirmwareVersion------");

      String command = "";
      late Uint8List bytesCommand;
      late List<int> crc;

      if (isChannel) {
        command = "2001${channelId}14";

        bytesCommand = hexToBytes(command);
        crc = Crc16CcittKermit.computeChecksumBytes([bytesCommand[3]]);
      } else {
        command = "200314";
        bytesCommand = hexToBytes(command);
        crc = Crc16CcittKermit.computeChecksumBytes([bytesCommand[2]]);
      }
      final builder = BytesBuilder();
      builder.add(bytesCommand);
      builder.add(crc);
      Uint8List sendBytes = builder.toBytes();
      print("[SENDING] ${bytesToHex(sendBytes)}");
      final response = await comm!.sendCommand(sendBytes);

      print(
        "[RAW FW RESPONSE] ${response != null ? bytesToHex(response) : "null"}",
      );

      return response;
    } catch (e) {
      print("❌ Dongle_GetFirmwareVersion ERROR: $e");
      return null;
    }
  }

  Future<Uint8List?> resetDongle() async {
    try {
      print("------ Inside Dongle_Reset ------");

      String commandBase = isChannel ? "2001${channelId}01" : "200301";

      Uint8List bytesCommand = hexToBytes(commandBase);

      return await comm!.sendCommand(bytesCommand);
    } catch (e) {
      print("❌ Reset Error: $e");
      return null;
    }
  }

  Future<Uint8List?> dongleGetProtocol() async {
    String command;

    if (isChannel) {
      command = "2001${channelId}03";
    } else {
      command = "200303";
    }

    Uint8List bytes = hexToBytes(command);
    return await comm!.sendCommand(bytes);
  }

  Future<Uint8List?> dongleSetProtocol(int protocolVersion) async {
    String protoHex = protocolVersion
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();

    String commandBase;
    Uint8List bytesToHash;

    if (isChannel) {
      commandBase = "2002${channelId}02$protoHex";
      Uint8List fullBytes = hexToBytes(commandBase);
      bytesToHash = Uint8List.fromList([fullBytes[3], fullBytes[4]]);
    } else {
      commandBase = "200402$protoHex";
      Uint8List fullBytes = hexToBytes(commandBase);
      bytesToHash = Uint8List.fromList([fullBytes[2], fullBytes[3]]);
    }
    int crcVal = Crc16CcittKermit.computeChecksum(bytesToHash);
    final builder = BytesBuilder();
    builder.add(hexToBytes(commandBase));
    builder.addByte((crcVal >> 8) & 0xFF);
    builder.addByte(crcVal & 0xFF);

    Uint8List finalPacket = builder.toBytes();
    return await comm!.sendCommand(finalPacket);
  }

  Future<Uint8List?> updateFirmware(String url) async {
    print("------Dongle_WriteSSID------");

    try {
      int payloadLen = (url.length ~/ 2) + 2;
      String lengthHex = payloadLen
          .toRadixString(16)
          .padLeft(2, '0')
          .toUpperCase();
      String commandBase = "20${lengthHex}0019${url}00";
      Uint8List bytesCommand = hexToBytes(commandBase);
      Uint8List outArray = bytesCommand.sublist(3);
      List<int> checksum = Crc16CcittKermit.computeChecksumBytes(outArray);
      String crcHex = checksum
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      Uint8List sendBytes = hexToBytes(commandBase + crcHex);
      print("[FW_UPDATE] Sending: ${bytesToHex(sendBytes)}");
      var response = await comm!.sendCommand(sendBytes);
      return response;
    } catch (e) {
      print("Error in updateFirmware: $e");
      return null;
    }
  }

  Future<List<IvnResponseArrayStatus>?> setIvnFrame(
    List<String> frameIDC,
  ) async {
    List<IvnResponseArrayStatus> responseList = [];
    IvnResponseArrayStatus ivnResponseArrayStatus;

    try {
      // Loop through each frame ID provided
      for (var frame in frameIDC) {
        print("------SET_IVN FRAME------");

        String command = "";
        String crc = "";

        // 1. Frame and Command Preparation
        if (isChannel) {
          if (frame.length == 8) {
            command =
                "2005$channelId"
                "20$frame";
            Uint8List bytesCommand = hexToUint8List(command);
            // Compute CRC from index 3 to 7
            crc = Crc16CcittKermit.computeChecksum(
              bytesCommand.sublist(3, 8),
            ).toRadixString(16).padLeft(4, '0');
          } else {
            command =
                "2003$channelId"
                "20$frame";
            Uint8List bytesCommand = hexToUint8List(command);
            // Compute CRC from index 3 to 5
            crc = Crc16CcittKermit.computeChecksum(
              bytesCommand.sublist(3, 6),
            ).toRadixString(16).padLeft(4, '0');
          }
        } else {
          if (frame.length == 8) {
            command = "200720$frame";
            Uint8List bytesCommand = hexToUint8List(command);
            // Compute CRC from index 2 to 6
            crc = Crc16CcittKermit.computeChecksum(
              bytesCommand.sublist(2, 7),
            ).toRadixString(16).padLeft(4, '0');
          } else {
            command = "200520$frame";
            Uint8List bytesCommand = hexToUint8List(command);
            // Compute CRC from index 2 to 4
            crc = Crc16CcittKermit.computeChecksum(
              bytesCommand.sublist(2, 5),
            ).toRadixString(16).padLeft(4, '0');
          }
        }

        // 2. Transmission
        Uint8List sendBytes = hexToUint8List(command + crc);
        var response = await comm!.sendCommand(sendBytes);

        if (response == null) continue;

        Uint8List ecuResponseBytes = response;
        String dataStatus = "";
        Uint8List? actualDataBytes;

        // 3. Initial Response Decoding
        Map<String, dynamic> decodeResult;
        if (isChannel) {
          decodeResult = ResponseArrayDecoding.checkResponseIVNwithChannel(
            ecuResponseBytes,
            sendBytes,
            "",
          );
        } else {
          decodeResult = ResponseArrayDecoding.checkResponseIVN(
            ecuResponseBytes,
            sendBytes,
            "",
          );
        }

        actualDataBytes = decodeResult["dataArray"];
        dataStatus = decodeResult["status"];

        // 4. Handle READAGAIN loop
        if (dataStatus == "READAGAIN") {
          while (dataStatus == "READAGAIN") {
            var responseReadAgain = await comm!.readData();
            if (responseReadAgain == null) break;

            Uint8List ecuResponseReadBytes = responseReadAgain;

            // Note: Standard CheckResponse used in the C# loop
            Map<String, dynamic> reReadResult =
                ResponseArrayDecoding.checkResponse(
                  ecuResponseReadBytes,
                  sendBytes,
                );

            dataStatus = reReadResult["status"];
            Uint8List? actualReadBytes = reReadResult["dataArray"];

            ivnResponseArrayStatus = IvnResponseArrayStatus(
              frame: frame,
              ecuResponse: ecuResponseReadBytes,
              ecuResponseStatus: dataStatus,
              actualDataBytes: actualReadBytes,
            );

            responseList.add(ivnResponseArrayStatus);

            // Detailed Logging
            _logDiagnosticInfo(ecuResponseReadBytes, ivnResponseArrayStatus);
          }
        } else {
          // 5. Success Path (No READAGAIN needed)
          ivnResponseArrayStatus = IvnResponseArrayStatus(
            frame: frame,
            ecuResponse: ecuResponseBytes,
            ecuResponseStatus: dataStatus,
            actualDataBytes: actualDataBytes,
          );

          responseList.add(ivnResponseArrayStatus);

          if (ivnResponseArrayStatus.actualDataBytes == null) {
            print("Command BT ACTUAL RESPONSE = NULL");
          } else {
            print(
              "Command BT ACTUAL RESPONSE = ${byteArrayToHex(ivnResponseArrayStatus.actualDataBytes!)}",
            );
          }
        }
      }

      return responseList;
    } catch (e) {
      print("Error in setIvnFrame: $e");
      return null;
    }
  }

  void _logDiagnosticInfo(Uint8List rawRx, IvnResponseArrayStatus status) {
    print("------EXTRA READ DATA START ------");
    if (status.ecuResponse != null) {
      print("------ECUResponse ------ ${byteArrayToHex(rawRx)}");
    }
    if (status.actualDataBytes != null) {
      print(
        "------ActualDataBytes ------ ${byteArrayToHex(status.actualDataBytes!)}",
      );
    }
    print("------ECUResponseStatus ------ ${status.ecuResponseStatus}");
    print("------EXTRA READ DATA END ------");
  }

  Uint8List hexToUint8List(String hex) {
    hex = hex.replaceAll(' ', '');
    if (hex.length % 2 != 0) hex = '0$hex';
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  Uint8List hexStringToByteArray(String hex) {
    hex = hex.replaceAll(" ", "");

    final bytes = Uint8List(hex.length ~/ 2);

    for (int i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }

    return bytes;
  }

  String byteArrayToString(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }



  Future<ResponseArrayStatus> can2xTxRx(int framelength, String txdata) async {
    ResponseArrayStatus responseStructure;

    try {
      print("------ENTER CAN_TxRx------");

      print("[INFO] Semaphore acquired at ${DateTime.now()}");

      logs.add(SessionLogsModel(header: "Tx", message: txdata));

      dynamic response;
      int dataLength = framelength + 2; // for CRC
      String command = "";

      if (isChannel) {
        int firstByte = 0x40 | ((framelength >> 8) & 0x0F);
        int secondByte = framelength & 0xFF;
        command =
            firstByte.toRadixString(16).padLeft(2, '0') +
            secondByte.toRadixString(16).padLeft(2, '0') +
            channelId! +
            txdata;
      } else {
        int firstByte = 0x40 | ((dataLength >> 8) & 0x0F);
        int secondByte = dataLength & 0xFF;
        command =
            firstByte.toRadixString(16).padLeft(2, '0') +
            secondByte.toRadixString(16).padLeft(2, '0') +
            txdata;
      }

      print("[DEBUG] Command before CRC: $command");

      hexToUint8List(command);
      Uint8List crcBytesComputation = hexToUint8List(txdata);
      String crc = Crc16CcittKermit.computeChecksum(
        crcBytesComputation,
      ).toRadixString(16).padLeft(4, '0').toUpperCase();

      print("[DEBUG] CRC Computed: $crc");

      Uint8List sendBytes = hexToUint8List(command + crc);
      print("[DEBUG] Full Packet to Send: ${byteArrayToHex(sendBytes)}");

      int noOfTimesSent = 0;

      print("[INFO] Sending attempt #${noOfTimesSent + 1}");

      if (comm!.connectivity == Connectivity.rp1210WiFi ||
          comm!.connectivity == Connectivity.rp1210Usb ||
          comm!.connectivity == Connectivity.canfdUSB ||
          comm!.connectivity == Connectivity.canFdWiFi) {
        print("[INFO] Using RP1210SendMessage path");
        response = await rp1210SendMessage(crcBytesComputation);
      } else if (comm!.connectivity == Connectivity.doipUsb ||
          comm!.connectivity == Connectivity.doipWiFi) {
        print("[INFO] Using RP1210DoipSendMessage path");
        response = await rp1210DoipSendMessage(crcBytesComputation);
      } else {
        print("[INFO] Using regular SendCommand path");
        response = await comm!.sendCommand(sendBytes);
      }

      noOfTimesSent++;
      print(
        "[INFO] Response received: ${response == null ? 'null' : byteArrayToHex(response as Uint8List)}",
      );

      if (response != null) {
        Uint8List ecuResponseBytes = response as Uint8List;
        String str = utf8.decode(ecuResponseBytes, allowMalformed: true);

        if (str.contains("Dongle disconnected") ||
            str.contains("No Resp From Dongle")) {
          print("[ERROR] Dongle disconnected or no response");
          responseStructure = ResponseArrayStatus(ecuResponseStatus: str);
          logs.add(
            SessionLogsModel(
              header: "Rx",
              status: responseStructure.ecuResponseStatus,
            ),
          );
          return responseStructure;
        }

        Uint8List actualDataBytes = Uint8List(0);
        String dataStatus = "";

        if (comm!.connectivity == Connectivity.rp1210WiFi ||
            comm!.connectivity == Connectivity.rp1210Usb ||
            comm!.connectivity == Connectivity.canfdUSB ||
            comm!.connectivity == Connectivity.canFdWiFi ||
            comm!.connectivity == Connectivity.doipUsb ||
            comm!.connectivity == Connectivity.doipWiFi) {
          var decodeResult = ResponseArrayDecoding.checkResponseRP1210(
            ecuResponseBytes,
            crcBytesComputation,
          );
          actualDataBytes = decodeResult["dataArray"];
          dataStatus = decodeResult["status"];
        } else {
          if (isChannel) {
            var decodeResult = ResponseArrayDecoding.checkResponseWithChannel(
              ecuResponseBytes,
              sendBytes,
            );
            actualDataBytes = decodeResult["dataArray"];
            dataStatus = decodeResult["status"];
          } else {
            var decodeResult = ResponseArrayDecoding.checkResponse(
              ecuResponseBytes,
              sendBytes,
            );
            actualDataBytes = decodeResult["dataArray"];
            dataStatus = decodeResult["status"];
          }
        }

        print("[DEBUG] Response status: $dataStatus");

        if (dataStatus == "SENDAGAIN") {
          print("[INFO] SENDAGAIN triggered");
          if (noOfTimesSent <= 5) {
          } else {
            print("[ERROR] SENDAGAIN threshold crossed");
            responseStructure = ResponseArrayStatus(
              ecuResponse: ecuResponseBytes,
              ecuResponseStatus: "DONGLEERROR_SENDAGAINTHRESHOLDCROSSED",
              actualDataBytes: actualDataBytes,
            );
            return responseStructure;
          }
        } else if (dataStatus == "READAGAIN") {
          print("[INFO] READAGAIN triggered");
          int readRetry = 0;
          while (dataStatus == "READAGAIN" && readRetry < 5) {
            print("[INFO] Performing ReadData() attempt ${readRetry + 1}");
            var responseReadAgain = await comm!.readData();
            if (responseReadAgain == null) {
              readRetry++;
              await Future.delayed(Duration(milliseconds: 50));
              continue;
            }

            Uint8List ecuReadBytes = responseReadAgain;
            String strRead = utf8.decode(ecuReadBytes, allowMalformed: true);
            print("[DEBUG] ReadAgain Response: $strRead");

            if (strRead.contains("Dongle disconnected") ||
                strRead.contains("No Resp From Dongle")) {
              print("[ERROR] Dongle disconnected during READAGAIN");
              responseStructure = ResponseArrayStatus(
                ecuResponseStatus: strRead,
              );
              return responseStructure;
            }

            if (comm!.connectivity == Connectivity.rp1210WiFi ||
                comm!.connectivity == Connectivity.rp1210Usb ||
                comm!.connectivity == Connectivity.canfdUSB ||
                comm!.connectivity == Connectivity.canFdWiFi ||
                comm!.connectivity == Connectivity.doipUsb ||
                comm!.connectivity == Connectivity.doipWiFi) {
              var decodeResult = ResponseArrayDecoding.checkResponseRP1210(
                ecuReadBytes,
                crcBytesComputation,
              );
              actualDataBytes = decodeResult["dataArray"];
              dataStatus = decodeResult["status"];
            } else {
              if (isChannel) {
                var decodeResult =
                    ResponseArrayDecoding.checkResponseWithChannel(
                      ecuReadBytes,
                      sendBytes,
                    );
                actualDataBytes = decodeResult["dataArray"];
                dataStatus = decodeResult["status"];
              } else {
                var decodeResult = ResponseArrayDecoding.checkResponse(
                  ecuReadBytes,
                  sendBytes,
                );
                actualDataBytes = decodeResult["dataArray"];
                dataStatus = decodeResult["status"];
              }
            }

            readRetry++;
          }

          if (dataStatus == "READAGAIN") {
            print("[ERROR] READAGAIN timeout exceeded");
            return ResponseArrayStatus(ecuResponseStatus: "READ_TIMEOUT");
          }
        }

        responseStructure = ResponseArrayStatus(
          ecuResponse: ecuResponseBytes,
          ecuResponseStatus: dataStatus,
          actualDataBytes: actualDataBytes,
        );

        print("------ECU RESPONSE SUMMARY------");
        print("ECUResponse: ${byteArrayToHex(responseStructure.ecuResponse!)}");
        print(
          "ActualDataBytes: ${byteArrayToHex(responseStructure.actualDataBytes!)}",
        );
        print("ECUResponseStatus: ${responseStructure.ecuResponseStatus}");
      } else {
        print("[ERROR] Response is null, setting No Resp From Dongle");
        responseStructure = ResponseArrayStatus(
          ecuResponse: null,
          ecuResponseStatus: "No Resp From Dongle",
          actualDataBytes: null,
        );
      }

      return responseStructure;
    } catch (ex) {
      print("[EXCEPTION] $ex");
      responseStructure = ResponseArrayStatus(
        ecuResponse: null,
        ecuResponseStatus: ex.toString().contains("non-connected sockets")
            ? "No Resp From Dongle"
            : ex.toString(),
        actualDataBytes: null,
      );
      return responseStructure;
    } finally {
      print("[INFO] Semaphore released at ${DateTime.now()}");
      print("------EXIT CAN_TxRx------");
    }
  }

  String byteArrayToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  String bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  Future<Uint8List> canSetHardRxHeaderMask(String rxhdrmsk) async {
    print("------canSetHardRxHeaderMask------");

    String command = "";
    String crc = "";

    if (isChannel) {
      if (rxhdrmsk.length == 8) {
        // Standard ID or Extended ID length handling
        command = "2005" + channelId! + "20" + rxhdrmsk;
        Uint8List bytesCommand = hexToUint8List(command);

        // C# passes bytesCommand[3] through [7]
        // Dart sublist(start, end) where end is exclusive
        crc = Crc16CcittKermit.computeChecksum(
          bytesCommand.sublist(3, 8),
        ).toRadixString(16);
      } else {
        command = "2003" + channelId! + "20" + rxhdrmsk;
        Uint8List bytesCommand = hexToUint8List(command);

        // C# passes bytesCommand[3] through [5]
        crc = Crc16CcittKermit.computeChecksum(
          bytesCommand.sublist(3, 6),
        ).toRadixString(16);
      }
    } else {
      if (rxhdrmsk.length == 8) {
        command = "200720" + rxhdrmsk;
        Uint8List bytesCommand = hexToUint8List(command);

        // C# passes bytesCommand[2] through [6]
        crc = Crc16CcittKermit.computeChecksum(
          bytesCommand.sublist(2, 7),
        ).toRadixString(16);
      } else {
        command = "200520" + rxhdrmsk;
        Uint8List bytesCommand = hexToUint8List(command);

        // C# passes bytesCommand[2] through [4]
        crc = Crc16CcittKermit.computeChecksum(
          bytesCommand.sublist(2, 5),
        ).toRadixString(16);
      }
    }

    // Standardize CRC length to 4 hex characters (2 bytes)
    // C# checks for length 3 and pads 0. Dart uses padLeft for cleaner code.
    crc = crc.padLeft(4, '0');

    Uint8List sendBytes = hexToUint8List(command + crc);
    return sendBytes;
  }

  Future<ResponseArrayStatusivn> canIVNRxFrame(String frameId) async {
    ResponseArrayStatusivn frameResponse = ResponseArrayStatusivn();

    try {
      // 1. Set the Hardware Filter/Header Mask
      // This sends the configuration command to the dongle to listen for a specific ID
      Uint8List sendBytes = await canSetHardRxHeaderMask(frameId);

      // 2. Send the command and get initial response
      var response = await comm!.sendCommand(sendBytes);
      if (response == null) {
        return ResponseArrayStatusivn(ecuResponseStatus: "NULL_RESPONSE");
      }

      Uint8List ecuResponseBytes = response;
      String dataStatus = "";
      Uint8List? actualDataBytes;

      // 3. Initial Check using the IVN Decoders
      Map<String, dynamic> decodeResult;
      if (isChannel) {
        decodeResult = ResponseArrayDecoding.checkResponseIVNwithChannel(
          ecuResponseBytes,
          sendBytes,
          "",
        );
      } else {
        decodeResult = ResponseArrayDecoding.checkResponseIVN(
          ecuResponseBytes,
          sendBytes,
          "",
        );
      }

      actualDataBytes = decodeResult["dataArray"];
      dataStatus = decodeResult["status"];

      // 4. Handle READAGAIN loop (Fragmented data)
      if (dataStatus == "READAGAIN") {
        while (dataStatus == "READAGAIN") {
          var responseReadAgain = await comm!.readData();
          if (responseReadAgain == null) break;

          Uint8List ecuResponseReadBytes = responseReadAgain;
          Map<String, dynamic> reReadResult;

          if (isChannel) {
            reReadResult = ResponseArrayDecoding.checkResponseWithChannel(
              ecuResponseReadBytes,
              sendBytes,
            );
          } else {
            reReadResult = ResponseArrayDecoding.checkResponse(
              ecuResponseReadBytes,
              sendBytes,
            );
          }

          dataStatus = reReadResult["status"];
          Uint8List? actualReadBytes = reReadResult["dataArray"];

          frameResponse = ResponseArrayStatusivn(
            ecuResponseStatus: dataStatus,
            actualFrameBytes: actualReadBytes,
          );

          // Logging logic
          print("------ EXTRA READ DATA START ------");
          if (frameResponse.actualFrameBytes != null) {
            print(
              "------ ECUResponse ------ ${byteArrayToHex(ecuResponseReadBytes)}",
            );
            print(
              "------ ActualDataBytes ------ ${byteArrayToHex(frameResponse.actualFrameBytes!)}",
            );
          }
          print(
            "------ ECUResponseStatus ------ ${frameResponse.ecuResponseStatus}",
          );
          print("------ EXTRA READ DATA END ------");
        }
      } else {
        // 5. Normal Success path
        frameResponse = ResponseArrayStatusivn(
          ecuResponseStatus: dataStatus,
          actualFrameBytes: actualDataBytes,
        );

        if (frameResponse.actualFrameBytes == null) {
          print("Command BT ACTUAL RESPONSE = NULL");
        } else {
          print(
            "Command BT ACTUAL RESPONSE = ${byteArrayToHex(frameResponse.actualFrameBytes!)}",
          );
        }
      }

      return frameResponse;
    } catch (ex) {
      print("Exception in canIVNRxFrame: $ex");
      return ResponseArrayStatusivn(
        ecuResponseStatus: "NULL_ERROR",
        actualFrameBytes: null,
      );
    }
  }

  Protocol currentProtocol = Protocol.ISO15765_250KB_11BIT_CAN;

  Future<dynamic> canSetTxHeader(String txHeader) async {
    print("------CAN_SetTxHeader------");

    String command = "";
    List<int> crcInput = [];

    bool is11Bit = [
      Protocol.ISO15765_250KB_11BIT_CAN,
      Protocol.ISO15765_500KB_11BIT_CAN,
      Protocol.ISO15765_1MB_11BIT_CAN,
      Protocol.I250KB_11BIT_CAN,
      Protocol.I500KB_11BIT_CAN,
      Protocol.I1MB_11BIT_CAN,
      Protocol.OE_IVN_250KBPS_11BIT_CAN,
      Protocol.OE_IVN_500KBPS_11BIT_CAN,
      Protocol.OE_IVN_1MBPS_11BIT_CAN,
      Protocol.CANOPEN_125KBPS_11BIT_CAN,
      Protocol.CANOPEN_500KBPS_11BIT_CAN,
      Protocol.XMODEM_125KBPS_11BIT_CAN,
      Protocol.XMODEM_500KBPS_11BIT_CAN,
    ].contains(currentProtocol);

    bool is29Bit = [
      Protocol.ISO15765_250Kb_29BIT_CAN,
      Protocol.ISO15765_500KB_29BIT_CAN,
      Protocol.ISO15765_1MB_29BIT_CAN,
      Protocol.I250Kb_29BIT_CAN,
      Protocol.I500KB_29BIT_CAN,
      Protocol.I1MB_29BIT_CAN,
      Protocol.OE_IVN_250KBPS_29BIT_CAN,
      Protocol.OE_IVN_500KBPS_29BIT_CAN,
      Protocol.OE_IVN_1MBPS_29BIT_CAN,
      Protocol.XMODEM_500KBPS_29BIT_CAN,
      Protocol.XMODEM_125KBPS_29BIT_CAN,
    ].contains(currentProtocol);

    bool isKWP = [
      Protocol.ISO14230_4KWP_FASTINIT_80,
      Protocol.ISO14230_4KWP_FASTINIT_C0,
    ].contains(currentProtocol);

    // 2. Build Command and Select CRC Range
    if (is11Bit) {
      if (isChannel) {
        command =
            "2003$channelId"
            "04$txHeader";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(3, 6); // bytes[3], [4], [5]
      } else {
        command = "200504$txHeader";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(2, 5); // bytes[2], [3], [4]
      }
    } else if (is29Bit) {
      if (isChannel) {
        command =
            "2005$channelId"
            "04$txHeader";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(3, 8); // bytes[3] through [7]
      } else {
        command = "200704$txHeader";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(2, 7); // bytes[2] through [6]
      }
    } else if (isKWP) {
      if (isChannel) {
        command =
            "2002$channelId"
            "04$txHeader";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(3, 5); // bytes[3], [4]
      } else {
        command = "200404$txHeader";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(2, 4); // bytes[2], [3]
      }
    }

    List<int> crcValue = Crc16CcittKermit.computeChecksumBytes(crcInput);

    // Maps each byte to a 2-character hex string and joins them together
    String crcHex = crcValue
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
    // 4. Send
    Uint8List sendBytes = Uint8List.fromList(hex.decode(command + crcHex));
    return await comm!.sendCommand(sendBytes);
  }

  Future<dynamic> canGetTxHeader() async {
    print("------CAN_GetTxHeader------");

    String command = "";
    List<int> crcInput = [];

    if (isChannel) {
      // Structure: 0x20 0x01 [ChannelId] 0x05
      command =
          "2001$channelId"
          "05";
      var bytes = hex.decode(command);
      // C# code: bytesCommand[3]
      crcInput = [bytes[3]];
    } else {
      // Structure: 0x20 0x03 0x05
      command = "200305";
      var bytes = hex.decode(command);
      // C# code: bytesCommand[2]
      crcInput = [bytes[2]];
    }

    List<int> crcValue = Crc16CcittKermit.computeChecksumBytes(crcInput);
    // Maps each byte to a 2-character hex string and joins them together
    String crcHex = crcValue
        .map((byte) => byte.toRadixString(16).padLeft(4, '0'))
        .join('')
        .toUpperCase();

    Uint8List sendBytes = Uint8List.fromList(hex.decode(command + crcHex));
    return await comm!.sendCommand(sendBytes);
  }

  Future<dynamic> canSetRxHeaderMask(String rxhdrmsk) async {
    print("------CAN_SetRxHeaderMask------");

    String command = "";
    List<int> crcInput = [];

    bool is11Bit = [
      Protocol.ISO15765_250KB_11BIT_CAN,
      Protocol.ISO15765_500KB_11BIT_CAN,
      Protocol.ISO15765_1MB_11BIT_CAN,
      Protocol.I250KB_11BIT_CAN,
      Protocol.I500KB_11BIT_CAN,
      Protocol.I1MB_11BIT_CAN,
      Protocol.OE_IVN_250KBPS_11BIT_CAN,
      Protocol.OE_IVN_500KBPS_11BIT_CAN,
      Protocol.OE_IVN_1MBPS_11BIT_CAN,
      Protocol.CANOPEN_125KBPS_11BIT_CAN,
      Protocol.CANOPEN_500KBPS_11BIT_CAN,
      Protocol.XMODEM_125KBPS_11BIT_CAN,
      Protocol.XMODEM_500KBPS_11BIT_CAN,
    ].contains(currentProtocol);

    bool is29Bit = [
      Protocol.ISO15765_250Kb_29BIT_CAN,
      Protocol.ISO15765_500KB_29BIT_CAN,
      Protocol.ISO15765_1MB_29BIT_CAN,
      Protocol.I250Kb_29BIT_CAN,
      Protocol.I500KB_29BIT_CAN,
      Protocol.I1MB_29BIT_CAN,
      Protocol.OE_IVN_250KBPS_29BIT_CAN,
      Protocol.OE_IVN_500KBPS_29BIT_CAN,
      Protocol.OE_IVN_1MBPS_29BIT_CAN,
      Protocol.XMODEM_500KBPS_29BIT_CAN,
      Protocol.XMODEM_125KBPS_29BIT_CAN,
    ].contains(currentProtocol);

    bool isKWP = [
      Protocol.ISO14230_4KWP_FASTINIT_80,
      Protocol.ISO14230_4KWP_FASTINIT_C0,
    ].contains(currentProtocol);
    if (is11Bit) {
      if (isChannel) {
        command =
            "2003$channelId"
            "06$rxhdrmsk";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(3, 6); // Equivalent to bytes[3], [4], [5]
      } else {
        command = "200506$rxhdrmsk";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(2, 5); // Equivalent to bytes[2], [3], [4]
      }
    } else if (is29Bit) {
      if (isChannel) {
        command =
            "2005$channelId"
            "06$rxhdrmsk";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(3, 8); // Equivalent to bytes[3] through [7]
      } else {
        command = "200706$rxhdrmsk";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(2, 7); // Equivalent to bytes[2] through [6]
      }
    } else if (isKWP) {
      if (isChannel) {
        command =
            "2002$channelId"
            "06$rxhdrmsk";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(3, 5); // Equivalent to bytes[3], [4]
      } else {
        command = "200406$rxhdrmsk";
        var bytes = hex.decode(command);
        crcInput = bytes.sublist(2, 4); // Equivalent to bytes[2], [3]
      }
    }
    List<int> crcValue = Crc16CcittKermit.computeChecksumBytes(crcInput);
    String crcHex = crcValue
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');

    Uint8List sendBytes = Uint8List.fromList(hex.decode(command + crcHex));

    return await comm!.sendCommand(sendBytes);
  }

  Future<dynamic> canGetRxHeaderMask() async {
    print("------CAN_GetRxHeaderMask------");

    String command = "";
    List<int> crcInput = [];

    if (isChannel) {
      command =
          "2001$channelId"
          "07";
      var bytes = hex.decode(command);
      crcInput = [bytes[3]];
    } else {
      command = "200307";
      var bytes = hex.decode(command);
      crcInput = [bytes[2]];
    }
    List<int> crcValue = Crc16CcittKermit.computeChecksumBytes(crcInput);
    String crcHex = crcValue
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('');
    Uint8List sendBytes = Uint8List.fromList(hex.decode(command + crcHex));
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canGetP1Min() async {
    print("------CAN_GetP1Min------");

    String command = "";
    List<int> checksumBytes;

    if (isChannel) {
      command = "2001${channelId}0d";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        Uint8List.fromList([bytesCommand[3]]),
      );
    } else {
      command = "20030d";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        Uint8List.fromList([bytesCommand[2]]),
      );
    }
    String crcHex = checksumBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);

    print("[CAN_GetP1Min] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canSetP1Min(String p1min) async {
    print("------CAN_SetP2Max------");

    String command = "";
    List<int> checksumBytes;

    if (isChannel) {
      command = "2002${channelId}0c$p1min";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(3, 6),
      );
    } else {
      command = "20040c$p1min";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(2, 5),
      );
    }
    String crcHex = checksumBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_SetP2Max] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canSetP2Max(String p2max) async {
    print("------CAN_SetP2Max------");

    String command = "";
    List<int> checksumBytes;

    if (isChannel) {
      command = "2003${channelId}0e$p2max";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(3, 6),
      );
    } else {
      command = "20050e$p2max";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(2, 5),
      );
    }
    String crcHex = checksumBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_SetP2Max] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canGetP2Max() async {
    print("------CAN_GetP2Max------");

    String command = "";
    List<int> checksumBytes;

    if (isChannel) {
      command = "2001${channelId}0f";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        Uint8List.fromList([bytesCommand[3]]),
      );
    } else {
      command = "20030f";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        Uint8List.fromList([bytesCommand[2]]),
      );
    }
    String crcHex = checksumBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_GetP2Max] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Uint8List txArray = Uint8List(0);
  Uint8List rxArray = Uint8List(0);

  Future<Uint8List?> canStartTP() async {
    print("------CAN_StartTP------");
    if (comm!.connectivity.value == Connectivity.usb ||
        comm!.connectivity.value == Connectivity.wiFi ||
        comm!.connectivity.value == Connectivity.ble) {
      String command = "";
      List<int> checksumBytes;
      if (isChannel) {
        command = "2001${channelId}10";
        Uint8List bytesCommand = hexToBytes(command);
        checksumBytes = Crc16CcittKermit.computeChecksumBytes(
          Uint8List.fromList([bytesCommand[3]]),
        );
      } else {
        command = "200310";
        Uint8List bytesCommand = hexToBytes(command);
        checksumBytes = Crc16CcittKermit.computeChecksumBytes(
          Uint8List.fromList([bytesCommand[2]]),
        );
      }
      String crcHex = checksumBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      Uint8List sendBytes = hexToBytes(command + crcHex);
      return await comm!.sendCommand(sendBytes);
    } else {
      final Uint8List message = Uint8List(7);
      message[0] = (SubCommandId.setTesterPresent.value >> 8) & 0xFF;
      message[1] = SubCommandId.setTesterPresent.value & 0xFF;
      message[2] = (txArray[0] == 0x00) ? 0 : 1;
      message.setRange(3, 7, txArray.sublist(0, 4));
      Uint8List? command = getRP1210Command(
        DWCommandId.sendCommand as int,
        message,
      );
      print("[CAN_StartTP] Sending RP1210 Command: ${bytesToHex(command)}");
      return await comm!.sendCommand(command);
    }
  }

  Future<Uint8List?> canStopTP() async {
    print("------CAN_StopTP------");
    final currentConn = comm!.connectivity.value;
    if (currentConn == Connectivity.usb ||
        currentConn == Connectivity.wiFi ||
        currentConn == Connectivity.ble) {
      String command = "";
      List<int> checksumBytes;
      if (isChannel) {
        command = "2001${channelId}11";
        Uint8List bytesCommand = hexToBytes(command);
        checksumBytes = Crc16CcittKermit.computeChecksumBytes(
          Uint8List.fromList([bytesCommand[3]]),
        );
      } else {
        command = "200311";
        Uint8List bytesCommand = hexToBytes(command);
        checksumBytes = Crc16CcittKermit.computeChecksumBytes(
          Uint8List.fromList([bytesCommand[2]]),
        );
      }
      String crcHex = checksumBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return await comm!.sendCommand(hexToBytes(command + crcHex));
    } else {
      final Uint8List message = Uint8List(2);
      message[0] = (SubCommandId.stopTesterPresent.value >> 8) & 0xFF;
      message[1] = SubCommandId.stopTesterPresent.value & 0xFF;
      Uint8List? rp1210Cmd = getRP1210Command(
        DWCommandId.sendCommand as int,
        message,
      );
      print("[CAN_StopTP] Sending RP1210 Command: ${bytesToHex(rp1210Cmd)}");
      return await comm!.sendCommand(rp1210Cmd);
    }
  }

  Future<Uint8List?> setTesterPresent(String commValue) async {
    print("------CAN_SetTesterPresent (Padding)------");

    String command = "";
    List<int> checksumBytes;

    if (isChannel) {
      command = "2002${channelId}0c$commValue";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(3, 5),
      );
    } else {
      command = "200412$commValue";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(2, 4),
      );
    }
    String crcHex = checksumBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    Uint8List sendBytes = hexToBytes(command + crcHex);

    print("[SetTesterPresent] Sending: ${bytesToHex(sendBytes)}");

    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canStartPadding(String paddingByte) async {
    print("------CAN_StartPadding------");
    String command = "";
    List<int> checksumBytes;
    if (isChannel) {
      command = "2002${channelId}12$paddingByte";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(3, 5),
      );
    } else {
      command = "200412$paddingByte";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        bytesCommand.sublist(2, 4),
      );
    }
    String crcHex = checksumBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_StartPadding] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canStopPadding() async {
    print("------CAN_StopPadding------");

    String command = "";
    List<int> checksumBytes;
    if (isChannel) {
      command = "2001${channelId}13";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        Uint8List.fromList([bytesCommand[3]]),
      );
    } else {
      command = "200313";
      Uint8List bytesCommand = hexToBytes(command);
      checksumBytes = Crc16CcittKermit.computeChecksumBytes(
        Uint8List.fromList([bytesCommand[2]]),
      );
    }
    String crcHex = checksumBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_StopPadding] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> wifiWriteSSID(String ssidHex) async {
    print("------Wifi_WriteSSID------");
    String command = "";
    Uint8List bytesCommand;
    Uint8List outArray;
    if (isChannel) {
      int len = (ssidHex.length ~/ 2) + 3;
      String lenHex = len.toRadixString(16).padLeft(2, '0').toUpperCase();
      command = "20$lenHex$channelId" + "1601${ssidHex}00";
      bytesCommand = hexToBytes(command);
      outArray = bytesCommand.sublist(3);
    } else {
      int len = (ssidHex.length ~/ 2) + 5;
      String lenHex = len.toRadixString(16).padLeft(2, '0').toUpperCase();
      command = "20$lenHex" + "1601${ssidHex}00";
      bytesCommand = hexToBytes(command);
      outArray = bytesCommand.sublist(2);
    }
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(outArray);
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[Wifi_WriteSSID] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> wifiWritePassword(String passwordHex) async {
    print("------Wifi_WritePassword------");
    String command = "";
    Uint8List outArray;
    if (isChannel) {
      int len = (passwordHex.length ~/ 2) + 3;
      String lenHex = len.toRadixString(16).padLeft(2, '0').toUpperCase();
      command = "20$lenHex$channelId" + "1701${passwordHex}00";
      Uint8List bytesCommand = hexToBytes(command);
      outArray = bytesCommand.sublist(3);
    } else {
      int len = (passwordHex.length ~/ 2) + 5;
      String lenHex = len.toRadixString(16).padLeft(2, '0').toUpperCase();
      command = "20$lenHex" + "1701${passwordHex}00";
      Uint8List bytesCommand = hexToBytes(command);
      outArray = bytesCommand.sublist(2);
    }
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(outArray);
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[Wifi_WritePW] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canTxData(String txDataHex) async {
    print("------CAN_TxData------");
    String command = "40$txDataHex";
    Uint8List crcBytesComputation = hexToBytes(txDataHex);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      crcBytesComputation,
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_TxData] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> setBlkSeqCntr(String blkLenHex) async {
    print("------SetBlkSeqCntr------");
    String command = "200408$blkLenHex";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      bytesCommand.sublist(2, 4),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[SetBlkSeqCntr] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> getBlkSeqCntr() async {
    print("------GetBlkSeqCntr------");
    String command = "200309";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      Uint8List.fromList([bytesCommand[2]]),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[GetBlkSeqCntr] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> setSepTime(String sepTimeHex) async {
    print("------SetSepTime------");
    String command = "20040A$sepTimeHex";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      bytesCommand.sublist(2, 4),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[SetSepTime] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> getSepTime() async {
    print("------GetSepTime------");
    String command = "20030B";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      Uint8List.fromList([bytesCommand[2]]),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[GetSepTime] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canGetDefaultSSID() async {
    print("------CAN_Get Default SSID------");
    String command = "20042200";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      bytesCommand.sublist(2, 4),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_GetDefaultSSID] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canGetDefaultPassword() async {
    print("------CAN_Get Default Password------");
    String command = "20042300";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      bytesCommand.sublist(2, 4),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_GetDefaultPassword] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canGetUserSSID() async {
    print("------CAN_Get User SSID------");
    String command = "20042201";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      bytesCommand.sublist(2, 4),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_GetUserSSID] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Future<Uint8List?> canGetUserPassword() async {
    print("------CAN_Get User Password------");
    String command = "20042301";
    Uint8List bytesCommand = hexToBytes(command);
    List<int> checksum = Crc16CcittKermit.computeChecksumBytes(
      bytesCommand.sublist(2, 4),
    );
    String crcHex = checksum
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    Uint8List sendBytes = hexToBytes(command + crcHex);
    print("[CAN_GetUserPassword] Sending: ${bytesToHex(sendBytes)}");
    return await comm!.sendCommand(sendBytes);
  }

  Uint8List getRP1210Command(int dWCommandId, Uint8List message) {
    Uint8List clientId = Uint8List(2);
    Uint8List dwCommand = Uint8List(4);

    dwCommand[0] = (dWCommandId >> 24) & 0xFF;
    dwCommand[1] = (dWCommandId >> 16) & 0xFF;
    dwCommand[2] = (dWCommandId >> 8) & 0xFF;
    dwCommand[3] = dWCommandId & 0xFF;

    // 2. Total length: 4 (length bytes) + 2 (clientId) + 4 (command) + message.length
    int totalLength = 4 + clientId.length + dwCommand.length + message.length;

    Uint8List returnArr = Uint8List(totalLength);
    returnArr[0] = (totalLength >> 24) & 0xFF;
    returnArr[1] = (totalLength >> 16) & 0xFF;
    returnArr[2] = (totalLength >> 8) & 0xFF;
    returnArr[3] = totalLength & 0xFF;
    returnArr.setRange(4, 6, clientId); // Index 4, 5
    returnArr.setRange(6, 10, dwCommand); // Index 6, 7, 8, 9

    returnArr.setRange(10, totalLength, message); // Index 10 onwards

    return returnArr;
  }

  Future<bool> rp1210ClientConnect(String protocol) async {
    try {
      Uint8List bytes = Uint8List.fromList(
        ascii.encode(getRP1210ProtocolString(protocol)),
      );

      Uint8List message = Uint8List(bytes.length + 2);
      message.setRange(2, 2 + bytes.length, bytes);

      Uint8List? command = getRP1210Command(
        DWCommandId.clientConnect.value,
        message,
      );

      Uint8List? resp = await comm!.sendCommand(command);

      if (resp != null) {
        int status = _extractStatus(resp);
        if (status == 0 || status == 0x82) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<bool> rp1210ClientDisconnect() async {
    try {
      Uint8List? command = getRP1210Command(
        DWCommandId.clientDisconnect.value,
        Uint8List(0),
      );

      Uint8List? resp = await comm!.sendCommand(command);

      if (resp != null && _extractStatus(resp) == 0) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  // ================================
  // ReadVersion
  // ================================
  Future<String> rp1210ReadVersion() async {
    try {
      Uint8List? command = getRP1210Command(
        DWCommandId.readVersion.value,
        Uint8List(0),
      );

      Uint8List? resp = await comm!.sendCommand(command);

      if (resp != null && resp.length > 14) {
        return ascii.decode(resp.sublist(14));
      }
    } catch (_) {}

    return "";
  }

  Future<bool> rp1210SendCommand(
    Uint8List txArr,
    Uint8List rxArr,
    SubCommandId subCommandId,
  ) async {
    try {
      Uint8List message;

      print("🚀 rp1210SendCommand called for: $subCommandId");
      print(
        "TX Array: ${txArr.map((e) => e.toRadixString(16).padLeft(2, '0')).toList()}",
      );
      print(
        "RX Array: ${rxArr.map((e) => e.toRadixString(16).padLeft(2, '0')).toList()}",
      );

      if (subCommandId == SubCommandId.setFlowControl) {
        message = Uint8List(17);

        message[0] = (subCommandId.value >> 8) & 0xFF;
        message[1] = subCommandId.value & 0xFF;
        message[2] = (txArr[0] == 0x00) ? 0 : 1;

        message.setRange(3, 7, rxArr);
        message.setRange(8, 12, txArr);

        message[15] = 0xFF;
        message[16] = 0xFF;

        print(
          "FlowControl message: ${message.map((e) => e.toRadixString(16).padLeft(2, '0')).toList()}",
        );
      } else {
        message = Uint8List(13);

        message[0] = (SubCommandId.setMsgFilter.value >> 8) & 0xFF;
        message[1] = SubCommandId.setMsgFilter.value & 0xFF;
        message[2] = (txArr[0] == 0x00) ? 0 : 1;

        message[3] = 0xFF;
        message[4] = 0xFF;
        message[5] = 0xFF;
        message[6] = 0xFF;
        message[7] = 0xFF;

        message.setRange(8, 12, rxArr);

        print(
          "MsgFilter message: ${message.map((e) => e.toRadixString(16).padLeft(2, '0')).toList()}",
        );
      }

      Uint8List command = getRP1210Command(
        DWCommandId.sendCommand.value,
        message,
      );
      print(
        "Full command to send: ${command.map((e) => e.toRadixString(16).padLeft(2, '0')).toList()}",
      );

      Uint8List? resp = await comm!.sendCommand(command);
      print(
        "Response received: ${resp?.map((e) => e.toRadixString(16).padLeft(2, '0')).toList()}",
      );

      if (resp != null && _extractStatus(resp) == 0) {
        txArray = txArr;
        rxArray = rxArr;
        print("✅ Command executed successfully");
        return true;
      } else {
        print("⚠ Command failed with status: ${_extractStatus(resp!)}");
      }
    } catch (e) {
      print("💥 Exception in rp1210SendCommand: $e");
    }

    return false;
  }

  String getRP1210ProtocolString(String protocol) {
    if (comm!.connectivity == Connectivity.rp1210Usb ||
        comm!.connectivity == Connectivity.rp1210WiFi) {
      String rp;

      if (protocol.contains("250")) {
        rp = "ISO15765:Baud=250000,Channel=";
      } else if (protocol.contains("500")) {
        rp = "ISO15765:Baud=500000,Channel=";
      } else {
        rp = "ISO15765:Baud=1000000,Channel=";
      }

      rp += (channelId == "00") ? "1" : "0";
      return rp;
    }

    if (comm!.connectivity == Connectivity.canFdUsb ||
        comm!.connectivity == Connectivity.canFdWiFi) {
      String rp;

      if (protocol.contains("250")) {
        rp = "CANFD_ISO15765:Baud=250000:DBR=2000000,Channel=";
      } else if (protocol.contains("500")) {
        rp = "CANFD_ISO15765:Baud=500000:DBR=2000000,Channel=";
      } else {
        rp = "CANFD_ISO15765:Baud=1000000:DBR=2000000,Channel=";
      }

      rp += (channelId == "00") ? "1" : "0";
      return rp;
    }

    if (comm!.connectivity == Connectivity.doipUsb ||
        comm!.connectivity == Connectivity.doipWiFi) {
      return "ISO 13400-2:2012";
    }

    throw Exception("Unsupported connectivity");
  }

  int _extractStatus(Uint8List resp) {
    if (resp.length < 14) return -1;

    return ((resp[10] & 0xFF) << 24) |
        ((resp[11] & 0xFF) << 16) |
        ((resp[12] & 0xFF) << 8) |
        (resp[13] & 0xFF);
  }

  Future<Rp1210SendResult?> rp1210SendMessage(Uint8List payload) async {
    try {
      print("------ ENTER rp1210SendMessage ------");
      Fluttertoast.showToast(msg: "Preparing RP1210 message...");

      Uint8List message;
      bool isStandardRP =
          (comm!.connectivity.value == Connectivity.rp1210Usb ||
          comm!.connectivity.value == Connectivity.rp1210WiFi);

      print("[DEBUG] Connectivity: ${comm!.connectivity.value}");
      Fluttertoast.showToast(msg: "Connectivity: ${comm!.connectivity.value}");

      if (isStandardRP) {
        // Standard Format: 1 (How) + 4 (CAN ID) + 1 (FP/Spacer) + Payload
        message = Uint8List(1 + 4 + 1 + payload.length);
        message[0] = (txArray[0] == 0x00 ? 0 : 1); // How (Broadcast/Node)
        message.setRange(1, 5, txArray.sublist(0, 4));
        // index 5 remains 0x00 as spacer/flag
        message.setRange(6, 6 + payload.length, payload);

        print(
          "[DEBUG] Built Standard RP1210 Payload (Pre-Header): ${message.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-')}",
        );
        Fluttertoast.showToast(msg: "Standard RP1210 payload built");
      } else {
        // CAN FD Format: 1 (How) + 1 (Protocol) + 4 (CAN ID) + 1 (Spacer) + Payload
        message = Uint8List(1 + 1 + 4 + 1 + payload.length);
        message[0] = (txArray[0] == 0x00 ? 0 : 1);
        message[1] = 0x0F; // Protocol ID for CAN FD
        message.setRange(2, 6, txArray.sublist(0, 4));
        message.setRange(7, 7 + payload.length, payload);

        print(
          "[DEBUG] Built CAN-FD RP1210 Payload (Pre-Header): ${message.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-')}",
        );
        Fluttertoast.showToast(msg: "CAN-FD RP1210 payload built");
      }

      // Wrap the message in the 00-00-00-XX Length Header and Command ID
      Uint8List command = getRP1210Command(
        DWCommandId.sendMessage.value,
        message,
      );

      Fluttertoast.showToast(msg: "Command packet ready to send");

      print(
        "[DEBUG] Message Length Header: ${command.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join('')}",
      );

      final response = await comm!.sendCommand(command);

      if (response != null) {
        Fluttertoast.showToast(msg: "Response received from dongle");
      } else {
        print("[DEBUG] Response to SendCommand is NULL");
        Fluttertoast.showToast(msg: "No response from dongle");
      }

      return Rp1210SendResult(sentPacket: command, response: response);
    } catch (e) {
      print("[EXCEPTION] Error in rp1210SendMessage: $e");
      Fluttertoast.showToast(msg: "Exception: $e");
      return null;
    } finally {
      print("------ EXIT rp1210SendMessage ------");
      Fluttertoast.showToast(msg: "Exiting RP1210 sendMessage");
    }
  }

  Future<bool> rp1210DoipSetDeviceIp(
    Uint8List staticIp,
    Uint8List subnetMask,
    Uint8List gateWayIp,
  ) async {
    bool retStatus = false;
    try {
      Uint8List message = Uint8List(14);
      int subId = SubCommandId.setDeviceIp.index;
      message[0] = (subId >> 8) & 0xFF;
      message[1] = subId & 0xFF;
      message.setRange(2, 6, staticIp.sublist(0, 4));
      message.setRange(6, 10, subnetMask.sublist(0, 4));
      message.setRange(10, 14, gateWayIp.sublist(0, 4));
      Uint8List? command = getRP1210Command(
        DWCommandId.sendCommand.value,
        message,
      );
      var resp = await comm!.sendCommand(command);
      if (resp != null && resp.isNotEmpty && resp.every((byte) => byte == 0)) {
        retStatus = true;
      }
    } catch (e) {
      print("Error in RP1210DoipSetDeviceIp: $e");
      retStatus = false;
    }
    return retStatus;
  }

  Future<bool> rp1210DoipSetEcuIp(Uint8List ecuIp) async {
    bool retStatus = false;
    try {
      Uint8List message = Uint8List(6);
      int subId = SubCommandId.setEcuIp.index;
      message[0] = (subId >> 8) & 0xFF;
      message[1] = subId & 0xFF;
      message.setRange(2, 6, ecuIp.sublist(0, 4));
      Uint8List? command = getRP1210Command(
        DWCommandId.sendCommand.value,
        message,
      );
      var resp = await comm!.sendCommand(command);
      if (resp != null && resp.isNotEmpty && resp.every((byte) => byte == 0)) {
        retStatus = true;
      }
    } catch (e) {
      print("Error in RP1210DoipSetEcuIp: $e");
      retStatus = false;
    }
    return retStatus;
  }

  Future<Uint8List?> rp1210DoipSendMessage(
    Uint8List payload, {
    bool isRoutineActivation = false,
  }) async {
    try {
      Uint8List message;
      if (isRoutineActivation) {
        message = Uint8List(1 + 1 + 2 + 4 + 2 + 1 + 4);
        message[0] = 0x02;
        message[1] = 0xFD;
        message[2] = 0x00;
        message[3] = 0x05;
        message[7] = 0x07;
        message.setRange(8, 10, txArray.sublist(0, 2));
      } else {
        message = Uint8List(12 + payload.length);
        message[0] = 0x02;
        message[1] = 0xFD;
        message[2] = 0x80;
        message[3] = 0x01;
        int msgLen = 2 + 2 + payload.length;
        message[4] = (msgLen >> 24) & 0xFF;
        message[5] = (msgLen >> 16) & 0xFF;
        message[6] = (msgLen >> 8) & 0xFF;
        message[7] = msgLen & 0xFF;
        message.setRange(8, 10, txArray.sublist(0, 2));
        message.setRange(10, 12, rxArray.sublist(0, 2));
        message.setRange(12, 12 + payload.length, payload);
      }
      Uint8List? command = getRP1210Command(
        DWCommandId.doipSendMessage.value,
        message,
      );
      return await comm!.sendCommand(command);
    } catch (e) {
      print("Error in RP1210DoipSendMessage: $e");
      return null;
    }
  }
}
