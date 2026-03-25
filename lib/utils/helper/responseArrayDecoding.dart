import 'dart:typed_data';
import 'dart:developer' as developer;

class ResponseArrayDecoding {
  // Static variables to maintain state across calls (mimicking C# static fields)
  static bool firstposdongleackreceived = false;
  static String val = "";
  static String halfActualRespons = "";
  static int actualLenth = 0;

  /// Main decoding method mimicking the C# 'CheckResponse'
  /// Since Dart doesn't have 'out' parameters, we return a Map or a custom Model.
  static Map<String, dynamic> checkResponse(
    Uint8List pidBytesResponse,
    Uint8List requestBytes,
  ) {
    Uint8List dataArray = pidBytesResponse;
    String status = "NOERROR";

    try {
      var responseBytes = pidBytesResponse;
      var request = requestBytes;
      String expectedFrame = "";
      String reqType = "";
      int nextPacketIndex = 0;
      bool endOfPacket = false;
      int frameLen = 0;

      // --- Request Parsing ---
      if (request[0] == 0x20) {
        reqType = "CONFIGREQUEST";
        switch (request[2]) {
          case 0x01: // Reset Dongle
          case 0x02: // Set Protocol
          case 0x04: // Set Transmit Header
          case 0x06: // Set Receive Header
          case 0x08: // Set Block length
          case 0x0A: // Set separation time
          case 0x0C: // Set Min time
          case 0x0E: // Set Max wait time
          case 0x10: // Periodic tester present
          case 0x11: // Stop periodic tester present
          case 0x12: // Pad transmit
          case 0x13: // Stop padding
          case 0x15: // Bluetooth name change
          case 0x17: // Set multiple filters
            expectedFrame = "DONGLECONFIGACK";
            break;
          case 0x03: // Get Protocol
          case 0x05: // Get Transmit Header
          case 0x07: // Get Receive Header
          case 0x09: // Get Block length
          case 0x0B: // Get separation time
          case 0x0D: // Get Min time
          case 0x0F: // Get Max wait time
          case 0x14: // Get firmware version
            expectedFrame = "DONGLECONFIGRESPONSE";
            break;
        }
      } else if (request[0] == 0x40) {
        reqType = "DATAREQUEST";
        expectedFrame = "DONGLECONFIGACK";
      }

      // --- Parser Start ---
      nextPacketIndex = 0;
      endOfPacket = false;

      while (!endOfPacket) {
        // Range check to prevent crashes
        if (nextPacketIndex >= responseBytes.length) {
          status = "READAGAIN";
          endOfPacket = true;
          break;
        }

        if (responseBytes[nextPacketIndex] == 0x20) {
          frameLen = responseBytes[nextPacketIndex + 1];

          if (reqType == "CONFIGREQUEST") {
            endOfPacket = true;
            if (expectedFrame == "DONGLECONFIGRESPONSE") {
              int length = frameLen - 2;
              Uint8List responseArray = Uint8List(length);
              responseArray.setRange(
                0,
                length,
                responseBytes.sublist(
                  nextPacketIndex + 3,
                  nextPacketIndex + 3 + length,
                ),
              );
              dataArray = responseArray;
            }
          } else if (responseBytes[nextPacketIndex + 1] == 0x03) {
            // DATAREQUEST and dongle positive acknowledgement
            if (firstposdongleackreceived == true) {
              firstposdongleackreceived = false;
              endOfPacket = true;
              status = "NOERROR";
              developer.log(
                "------ Jugaad - Getting positive dongle ack frame for second time -------",
              );
              break;
            }

            nextPacketIndex += 5;
            firstposdongleackreceived = true;

            if (nextPacketIndex < responseBytes.length) {
              endOfPacket = false;
            } else {
              status = "READAGAIN";
              endOfPacket = true;
              break;
            }
          } else {
            // DATAREQUEST and dongle negative acknowledgement
            endOfPacket = true;
            firstposdongleackreceived = false;

            switch (responseBytes[3]) {
              case 0x10:
                status = "DONGLEERROR_COMMANDNOTSUPPORTED";
                break;
              case 0x12:
                status = "DONGLEERROR_INPUTNOTSUPPORTED";
                break;
              case 0x13:
                status = "DONGLEERROR_INVALIDFORMAT";
                break;
              case 0x14:
                status = "DONGLEERROR_INVALIDOPERATION";
                break;
              case 0x15:
                status = "DONGLEERROR_CRCFAILURE";
                break;
              case 0x16:
                status = "DONGLEERROR_PROTOCOLNOTSET";
                break;
              case 0x33:
                status = "DONGLEERROR_SECURITYACCESSDENIED";
                break;
            }
            status = "SENDAGAIN";
          }
        }
        // No response from ECU for P2MAX
        else if (((responseBytes[nextPacketIndex] & 0xF0) == 0x40) &&
            (responseBytes[nextPacketIndex + 1] == 0x02)) {
          status = "ECUERROR_NORESPONSEFROMECU";
          endOfPacket = true;
          firstposdongleackreceived = false;
          break;
        }
        // ECU Data Response (4x)
        else if (((responseBytes[nextPacketIndex] & 0xF0) == 0x40) ||
            halfActualRespons.isNotEmpty) {
          firstposdongleackreceived = false;

          var msgLen =
              ((responseBytes[nextPacketIndex] & 0x0F) << 8) +
              responseBytes[nextPacketIndex + 1];
          frameLen = msgLen;

          if (halfActualRespons.isEmpty) {
            actualLenth = msgLen;
          }

          // ECU Negative Response (7F)
          if (responseBytes[nextPacketIndex + 2] == 0x7F) {
            if (responseBytes[nextPacketIndex + 4] == 0x78) {
              // NRC 78: Request next packet
              nextPacketIndex += 7;
              endOfPacket = false;
              if (nextPacketIndex > responseBytes.length - 1) {
                status = "READAGAIN";
                endOfPacket = true;
                break;
              }
            } else {
              endOfPacket = true;
              // Map UDS Negative Response Codes
              switch (responseBytes[nextPacketIndex + 4]) {
                case 0x10:
                  status = "ECUERROR_GENERALREJECT";
                  break;
                case 0x11:
                  status = "ECUERROR_SERVICENOTSUPPORTED";
                  break;
                case 0x12:
                  status = "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
                  break;
                case 0x13:
                  status = "ECUERROR_INVALIDFORMAT";
                  break;
                case 0x14:
                  status = "ECUERROR_RESPONSETOOLONG";
                  break;
                case 0x21:
                  status = "ECUERROR_BUSYREPEATREQUEST";
                  break;
                case 0x22:
                  status = "ECUERROR_CONDITIONSNOTCORRECT";
                  break;
                case 0x24:
                  status = "ECUERROR_REQUESTSEQUENCEERROR";
                  break;
                case 0x31:
                  status = "ECUERROR_REQUESTOUTOFRANGE";
                  break;
                case 0x33:
                  status = "ECUERROR_SECURITYACCESSDENIED";
                  break;
                case 0x35:
                  status = "ECUERROR_INVALIDKEY";
                  break;
                case 0x36:
                  status = "ECUERROR_EXCEEDEDNUMBEROFATTEMPTS";
                  break;
                case 0x37:
                  status = "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED";
                  break;
                case 0x70:
                  status = "ECUERROR_UPLOADDOWNLOADNOTACCEPTED";
                  break;
                case 0x71:
                  status = "ECUERROR_TRANSFERDATASUSPENDED";
                  break;
                case 0x72:
                  status = "ECUERROR_GENERALPROGRAMMINGFAILURE";
                  break;
                case 0x73:
                  status = "ECUERROR_WRONGBLOCKSEQCOUNTER";
                  break;
                case 0x7E:
                  status = "ECUERROR_SUBFNNOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x7F:
                  status = "ECUERROR_SERVICENOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x81:
                  status = "ECUERROR_RPMTOOHIGH";
                  break;
                case 0x82:
                  status = "ECUERROR_RPMTOOLOW";
                  break;
                case 0x83:
                  status = "ECUERROR_ENGINEISRUNNING";
                  break;
                case 0x84:
                  status = "ECUERROR_ENGINEISNOTRUNNING";
                  break;
                case 0x85:
                  status = "ECUERROR_ENGINERUNTIMETOOLOW";
                  break;
                case 0x86:
                  status = "ECUERROR_TEMPTOOHIGH";
                  break;
                case 0x87:
                  status = "ECUERROR_TEMPTOOLOW";
                  break;
                case 0x88:
                  status = "ECUERROR_VEHSPEEDTOOHIGH";
                  break;
                case 0x89:
                  status = "ECUERROR_VEHSPEEDTOOLOW";
                  break;
                case 0x8A:
                  status = "ECUERROR_THROTTLETOOHIGH";
                  break;
                case 0x8B:
                  status = "ECUERROR_THROTTLETOOLOW";
                  break;
                case 0x8C:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINNEUTRAL";
                  break;
                case 0x8D:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINGEAR";
                  break;
                case 0x8F:
                  status = "ECUERROR_BRKPEDALNOTPRESSED";
                  break;
                case 0x90:
                  status = "ECUERROR_SHIFTERLEVERNOTINPARK";
                  break;
                case 0x91:
                  status = "ECUERROR_TRQCONVERTERCLUTCHLOCKED";
                  break;
                case 0x92:
                  status = "ECUERROR_VOLTAGETOOHIGH";
                  break;
                case 0x93:
                  status = "ECUERROR_VOLTAGETOOLOW";
                  break;
              }
            }
          }
          // Positive response from ECU
          else {
            endOfPacket = true;
            int length = frameLen - 2;
            Uint8List responseArray = Uint8List(length);

            val =
                "${byteArrayToHex(responseBytes)}, ${nextPacketIndex + 2}, ${byteArrayToHex(responseArray)}, 0, ${frameLen - 2}";
            developer.log("Array Copy Detail: $val");

            if (halfActualRespons.isNotEmpty) {
              halfActualRespons += byteArrayToHex(responseBytes);
              responseBytes = hexToUint8List(halfActualRespons);
              frameLen = actualLenth;
            }

            if ((responseBytes.length - 2) < responseBytes[1]) {
              status = "READAGAIN";
              halfActualRespons = byteArrayToHex(responseBytes);
            } else {
              if (halfActualRespons.isNotEmpty) {
                halfActualRespons = "";
                actualLenth = 0;
              }
              status = "NOERROR";
              // Manual copy logic
              for (int j = 0; j < (frameLen - 2); j++) {
                if (nextPacketIndex + 2 + j < responseBytes.length) {
                  responseArray[j] = responseBytes[nextPacketIndex + 2 + j];
                }
              }
              dataArray = responseArray;
            }
          }
        } else {
          status = "GENERALERROR_INVALIDRESPFROMDONGLE";
          firstposdongleackreceived = false;
          endOfPacket = true;
        }
      }
    } catch (ex, stack) {
      dataArray = Uint8List(0);
      status = "$val\n\n${ex.toString()}\n\n${stack.toString()}";
    }

    return {"dataArray": dataArray, "status": status};
  }

  // --- Static Helper Methods ---

  static String byteArrayToHex(Uint8List ba) {
    return ba
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  static Uint8List hexToUint8List(String hex) {
    hex = hex.replaceAll(' ', '');
    if (hex.length % 2 != 0) hex = '0$hex';
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  static Map<String, dynamic> checkResponseIVN(
    Uint8List pidBytesResponse,
    Uint8List requestBytes,
    String reqType1,
  ) {
    Uint8List? dataArray;
    String status = "NOERROR";

    try {
      var responseBytes = pidBytesResponse;
      var request = requestBytes;
      String expectedFrame = "";
      String reqType = "";
      int nextPacketIndex = 0;
      bool endOfPacket = false;
      int frameLen = 0;

      // 1. Determine Expected Frame based on Config Request (0x20)
      if (request[0] == 0x20) {
        switch (request[2]) {
          case 0x01: // Reset Dongle
          case 0x02: // Set Protocol
          case 0x04: // Set Transmit Header
          case 0x06: // Set Receive Header
          case 0x08: // Set Block length
          case 0x0A: // Set separation time
          case 0x0C: // Set Min time
          case 0x0E: // Set Max wait time
          case 0x10: // Tester Present periodic
          case 0x11: // Stop Tester Present
          case 0x12: // Pad transmit
          case 0x13: // Stop padding
          case 0x15: // BT name change
          case 0x17: // Set filters
            expectedFrame = "DONGLECONFIGACK";
            break;
          case 0x03: // Get Protocol
          case 0x05: // Get Transmit Header
          case 0x07: // Get Receive Header
          case 0x09: // Get Block length
          case 0x0B: // Get separation time
          case 0x0D: // Get Min time
          case 0x0F: // Get Max wait time
          case 0x14: // Get firmware version
            expectedFrame = "DONGLECONFIGRESPONSE";
            break;
        }
      }
      // 2. Data Request (0x40)
      else if (request[0] == 0x40) {
        reqType = "DATAREQUEST";
        expectedFrame = "DONGLECONFIGACK";
      }

      nextPacketIndex = 0;
      endOfPacket = false;

      // 3. Main Parser Loop
      while (!endOfPacket) {
        // Safety range check
        if (nextPacketIndex >= responseBytes.length) {
          endOfPacket = true;
          break;
        }

        // Dongle Response Header (0x20)
        if (responseBytes[nextPacketIndex] == 0x20) {
          frameLen = responseBytes[nextPacketIndex + 1];

          if (reqType == "CONFIGREQUEST") {
            endOfPacket = true;
            if (expectedFrame == "DONGLECONFIGRESPONSE") {
              int length = frameLen - 2;
              dataArray = responseBytes.sublist(
                nextPacketIndex + 3,
                nextPacketIndex + 3 + length,
              );
            }
          }
          // Positive Dongle Ack (0x03)
          else if (responseBytes[nextPacketIndex + 1] == 0x03) {
            if (firstposdongleackreceived == true) {
              firstposdongleackreceived = false;
              endOfPacket = true;
              status = "NOERROR";
              // log: Jugaad - second positive ack
              break;
            }

            nextPacketIndex += 5;
            firstposdongleackreceived = true;

            if (nextPacketIndex < responseBytes.length) {
              endOfPacket = false;
            } else {
              status = "READAGAIN";
              endOfPacket = true;
              break;
            }
          }
          // Negative Dongle Ack
          else {
            endOfPacket = true;
            firstposdongleackreceived = false;
            switch (responseBytes[3]) {
              case 0x10:
                status = "DONGLEERROR_COMMANDNOTSUPPORTED";
                break;
              case 0x12:
                status = "DONGLEERROR_INPUTNOTSUPPORTED";
                break;
              case 0x13:
                status = "DONGLEERROR_INVALIDFORMAT";
                break;
              case 0x14:
                status = "DONGLEERROR_INVALIDOPERATION";
                break;
              case 0x15:
                status = "DONGLEERROR_CRCFAILURE";
                break;
              case 0x16:
                status = "DONGLEERROR_PROTOCOLNOTSET";
                break;
              case 0x33:
                status = "DONGLEERROR_SECURITYACCESSDENIED";
                break;
            }
            status = "SENDAGAIN";
          }
        }
        // ECU Timeout (0x40 0x02)
        else if (((responseBytes[nextPacketIndex] & 0xF0) == 0x40) &&
            (responseBytes[nextPacketIndex + 1] == 0x02)) {
          status = "ECUERROR_NORESPONSEFROMECU";
          endOfPacket = true;
          firstposdongleackreceived = false;
          break;
        }
        // ECU Data Frame (0x4X)
        else if ((responseBytes[nextPacketIndex] & 0xF0) == 0x40) {
          firstposdongleackreceived = false;
          int msgLen =
              ((responseBytes[nextPacketIndex] & 0x0F) << 8) +
              responseBytes[nextPacketIndex + 1];
          frameLen = msgLen;

          // ECU Negative Response (7F)
          if (responseBytes[nextPacketIndex + 2] == 0x7F) {
            if (responseBytes[nextPacketIndex + 4] == 0x78) {
              nextPacketIndex += 7;
              endOfPacket = false;
              if (nextPacketIndex > responseBytes.length - 1) {
                status = "READAGAIN";
                endOfPacket = true;
                break;
              }
            } else {
              endOfPacket = true;
              int nrc = responseBytes[nextPacketIndex + 4];
              // Map ECU NRC codes
              switch (nrc) {
                case 0x10:
                  status = "ECUERROR_GENERALREJECT";
                  break;
                case 0x11:
                  status = "ECUERROR_SERVICENOTSUPPO0RTED";
                  break;
                case 0x12:
                  status = "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
                  break;
                case 0x13:
                  status = "ECUERROR_INVALIDFORMAT";
                  break;
                case 0x14:
                  status = "ECUERROR_RESPONSETOOLONG";
                  break;
                case 0x21:
                  status = "ECUERROR_BUSYREPEATREQUEST";
                  break;
                case 0x22:
                  status = "ECUERROR_CONDITIONSNOTCORRECT";
                  break;
                case 0x24:
                  status = "ECUERROR_REQUESTSEQUENCEERROR";
                  break;
                case 0x31:
                  status = "ECUERROR_REQUESTOUTOFRANGE";
                  break;
                case 0x33:
                  status = "ECUERROR_SECURITYACCESSDENIED";
                  break;
                case 0x35:
                  status = "ECUERROR_INVALIDKEY";
                  break;
                case 0x36:
                  status = "ECUERROR_EXCEEDEDNUMBEROFATTEMPTS";
                  break;
                case 0x37:
                  status = "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED";
                  break;
                case 0x70:
                  status = "ECUERROR_UPLOADDOWNLOADNOTACCEPTED";
                  break;
                case 0x71:
                  status = "ECUERROR_TRANSFERDATASUSPENDED";
                  break;
                case 0x72:
                  status = "ECUERROR_GENERALPROGRAMMINGFAILURE";
                  break;
                case 0x73:
                  status = "ECUERROR_WRONGBLOCKSEQCOUNTER";
                  break;
                case 0x7E:
                  status = "ECUERROR_SUBFNNOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x7F:
                  status = "ECUERROR_SERVICENOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x81:
                  status = "ECUERROR_RPMTOOHIGH";
                  break;
                case 0x82:
                  status = "ECUERROR_RPMTOOLOW";
                  break;
                case 0x83:
                  status = "ECUERROR_ENGINEISRUNNING";
                  break;
                case 0x84:
                  status = "ECUERROR_ENGINEISNOTRUNNING";
                  break;
                case 0x85:
                  status = "ECUERROR_ENGINERUNTIMETOOLOW";
                  break;
                case 0x86:
                  status = "ECUERROR_TEMPTOOHIGH";
                  break;
                case 0x87:
                  status = "ECUERROR_TEMPTOOLOW";
                  break;
                case 0x88:
                  status = "ECUERROR_VEHSPEEDTOOHIGH";
                  break;
                case 0x89:
                  status = "ECUERROR_VEHSPEEDTOOLOW";
                  break;
                case 0x8A:
                  status = "ECUERROR_THROTTLETOOHIGH";
                  break;
                case 0x8B:
                  status = "ECUERROR_THROTTLETOOLOW";
                  break;
                case 0x8C:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINNEUTRAL";
                  break;
                case 0x8D:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINGEAR";
                  break;
                case 0x8F:
                  status = "ECUERROR_BRKPEDALNOTPRESSED";
                  break;
                case 0x90:
                  status = "ECUERROR_SHIFTERLEVERNOTINPARK";
                  break;
                case 0x91:
                  status = "ECUERROR_TRQCONVERTERCLUTCHLOCKED";
                  break;
                case 0x92:
                  status = "ECUERROR_VOLTAGETOOHIGH";
                  break;
                case 0x93:
                  status = "ECUERROR_VOLTAGETOOLOW";
                  break;
              }
            }
          }
          // ECU Positive Response
          else {
            endOfPacket = true;
            int length = frameLen - 2;
            Uint8List responseArray = Uint8List(length);

            // Debug string construction
            val =
                "${byteArrayToHex(responseBytes)}, $nextPacketIndex, ${byteArrayToHex(responseArray)}, $frameLen";

            // Array.Copy(responseBytes, nextPacketIndex + 2, responseArray, 0, framelen - 2);
            responseArray.setRange(
              0,
              length,
              responseBytes.sublist(
                nextPacketIndex + 2,
                nextPacketIndex + 2 + length,
              ),
            );
            dataArray = responseArray;
          }
        } else {
          status = "GENERALERROR_INVALIDRESPFROMDONGLE";
          firstposdongleackreceived = false;
          endOfPacket = true;
        }
      }
    } catch (ex, stack) {
      dataArray = null;
      status = "$val\n\n${ex.toString()}\n\n${stack.toString()}";
    }

    return {"dataArray": dataArray, "status": status};
  }

  static Map<String, dynamic> checkResponseIVNwithChannel(
    Uint8List pidBytesResponse,
    Uint8List requestBytes,
    String reqType1,
  ) {
    Uint8List? dataArray;
    String status = "NOERROR";

    try {
      var responseBytes = pidBytesResponse;
      var request = requestBytes;
      String expectedFrame = "";
      String reqType = "";
      int nextPacketIndex = 0;
      bool endOfPacket = false;
      int frameLen = 0;

      // 1. Determine Expected Frame (Note: checking index [3] for Channel protocol)
      if (request[0] == 0x20) {
        switch (request[3]) {
          case 0x01: // Reset
          case 0x02: // Set Protocol
          case 0x04: // Set Tx Header
          case 0x06: // Set Rx Header
          case 0x08: // Block length
          case 0x0A: // Sep time
          case 0x0C: // Min time
          case 0x0E: // Max wait
          case 0x10: // Tester Present
          case 0x11: // Stop Tester Present
          case 0x12: // Pad
          case 0x13: // Stop Pad
          case 0x15: // BT Change
          case 0x17: // Filters
            expectedFrame = "DONGLECONFIGACK";
            break;
          case 0x03: // Get Protocol
          case 0x05: // Get Tx Header
          case 0x07: // Get Rx Header
          case 0x09: // Get Block Len
          case 0x0B: // Get Sep Time
          case 0x0D: // Get Min Time
          case 0x0F: // Get Max Wait
          case 0x14: // Get Firmware
            expectedFrame = "DONGLECONFIGRESPONSE";
            break;
        }
      } else if (request[0] == 0x40) {
        reqType = "DATAREQUEST";
        expectedFrame = "DONGLECONFIGACK";
      }

      nextPacketIndex = 0;
      endOfPacket = false;

      // 2. Main Parser Loop
      while (!endOfPacket) {
        if (nextPacketIndex >= responseBytes.length) {
          endOfPacket = true;
          break;
        }

        // Dongle Response Header (0x20)
        if (responseBytes[nextPacketIndex] == 0x20) {
          frameLen = responseBytes[nextPacketIndex + 1];

          if (reqType == "CONFIGREQUEST") {
            endOfPacket = true;
            if (expectedFrame == "DONGLECONFIGRESPONSE") {
              // Copy data starting from index 4
              dataArray = responseBytes.sublist(
                nextPacketIndex + 4,
                nextPacketIndex + 4 + frameLen,
              );
            }
          }
          // Positive Dongle Ack (0x01 for Channel variants)
          else if (responseBytes[nextPacketIndex + 1] == 0x01) {
            if (firstposdongleackreceived == true) {
              firstposdongleackreceived = false;
              endOfPacket = true;
              status = "NOERROR";
              break;
            }

            nextPacketIndex += 6; // Offset for channel data
            firstposdongleackreceived = true;

            if (nextPacketIndex < responseBytes.length) {
              endOfPacket = false;
            } else {
              status = "READAGAIN";
              endOfPacket = true;
              break;
            }
          } else {
            // Negative Dongle Ack
            endOfPacket = true;
            firstposdongleackreceived = false;
            switch (responseBytes[4]) {
              case 0x10:
                status = "DONGLEERROR_COMMANDNOTSUPPORTED";
                break;
              case 0x12:
                status = "DONGLEERROR_INPUTNOTSUPPORTED";
                break;
              case 0x13:
                status = "DONGLEERROR_INVALIDFORMAT";
                break;
              case 0x14:
                status = "DONGLEERROR_INVALIDOPERATION";
                break;
              case 0x15:
                status = "DONGLEERROR_CRCFAILURE";
                break;
              case 0x16:
                status = "DONGLEERROR_PROTOCOLNOTSET";
                break;
              case 0x33:
                status = "DONGLEERROR_SECURITYACCESSDENIED";
                break;
            }
            status = "SENDAGAIN";
          }
        }
        // ECU Timeout (0x40 0x00)
        else if (((responseBytes[nextPacketIndex] & 0xF0) == 0x40) &&
            (responseBytes[nextPacketIndex + 1] == 0x00)) {
          status = "ECUERROR_NORESPONSEFROMECU";
          endOfPacket = true;
          firstposdongleackreceived = false;
          break;
        }
        // ECU Data Frame (starts with 4X)
        else if ((responseBytes[nextPacketIndex] & 0xF0) == 0x40) {
          firstposdongleackreceived = false;
          int msgLen =
              ((responseBytes[nextPacketIndex] & 0x0F) << 8) +
              responseBytes[nextPacketIndex + 1];
          frameLen = msgLen;

          // ECU Negative Response (7F at index 3 for Channel logic)
          if (responseBytes[nextPacketIndex + 3] == 0x7F) {
            if (responseBytes[nextPacketIndex + 5] == 0x78) {
              nextPacketIndex += 8; // Skip pending frame
              endOfPacket = false;
              if (nextPacketIndex > responseBytes.length - 1) {
                status = "READAGAIN";
                endOfPacket = true;
                break;
              }
            } else {
              endOfPacket = true;
              int nrc = responseBytes[nextPacketIndex + 5];
              // Map ECU NRC codes
              switch (nrc) {
                case 0x10:
                  status = "ECUERROR_GENERALREJECT";
                  break;
                case 0x11:
                  status = "ECUERROR_SERVICENOTSUPPO0RTED";
                  break;
                case 0x12:
                  status = "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
                  break;
                case 0x13:
                  status = "ECUERROR_INVALIDFORMAT";
                  break;
                case 0x14:
                  status = "ECUERROR_RESPONSETOOLONG";
                  break;
                case 0x21:
                  status = "ECUERROR_BUSYREPEATREQUEST";
                  break;
                case 0x22:
                  status = "ECUERROR_CONDITIONSNOTCORRECT";
                  break;
                case 0x24:
                  status = "ECUERROR_REQUESTSEQUENCEERROR";
                  break;
                case 0x31:
                  status = "ECUERROR_REQUESTOUTOFRANGE";
                  break;
                case 0x33:
                  status = "ECUERROR_SECURITYACCESSDENIED";
                  break;
                case 0x35:
                  status = "ECUERROR_INVALIDKEY";
                  break;
                case 0x36:
                  status = "ECUERROR_EXCEEDEDNUMBEROFATTEMPTS";
                  break;
                case 0x37:
                  status = "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED";
                  break;
                case 0x70:
                  status = "ECUERROR_UPLOADDOWNLOADNOTACCEPTED";
                  break;
                case 0x71:
                  status = "ECUERROR_TRANSFERDATASUSPENDED";
                  break;
                case 0x72:
                  status = "ECUERROR_GENERALPROGRAMMINGFAILURE";
                  break;
                case 0x73:
                  status = "ECUERROR_WRONGBLOCKSEQCOUNTER";
                  break;
                case 0x7E:
                  status = "ECUERROR_SUBFNNOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x7F:
                  status = "ECUERROR_SERVICENOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x81:
                  status = "ECUERROR_RPMTOOHIGH";
                  break;
                case 0x82:
                  status = "ECUERROR_RPMTOOLOW";
                  break;
                case 0x83:
                  status = "ECUERROR_ENGINEISRUNNING";
                  break;
                case 0x84:
                  status = "ECUERROR_ENGINEISNOTRUNNING";
                  break;
                case 0x85:
                  status = "ECUERROR_ENGINERUNTIMETOOLOW";
                  break;
                case 0x86:
                  status = "ECUERROR_TEMPTOOHIGH";
                  break;
                case 0x87:
                  status = "ECUERROR_TEMPTOOLOW";
                  break;
                case 0x88:
                  status = "ECUERROR_VEHSPEEDTOOHIGH";
                  break;
                case 0x89:
                  status = "ECUERROR_VEHSPEEDTOOLOW";
                  break;
                case 0x8A:
                  status = "ECUERROR_THROTTLETOOHIGH";
                  break;
                case 0x8B:
                  status = "ECUERROR_THROTTLETOOLOW";
                  break;
                case 0x8C:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINNEUTRAL";
                  break;
                case 0x8D:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINGEAR";
                  break;
                case 0x8F:
                  status = "ECUERROR_BRKPEDALNOTPRESSED";
                  break;
                case 0x90:
                  status = "ECUERROR_SHIFTERLEVERNOTINPARK";
                  break;
                case 0x91:
                  status = "ECUERROR_TRQCONVERTERCLUTCHLOCKED";
                  break;
                case 0x92:
                  status = "ECUERROR_VOLTAGETOOHIGH";
                  break;
                case 0x93:
                  status = "ECUERROR_VOLTAGETOOLOW";
                  break;
              }
            }
          }
          // ECU Positive Response
          else {
            endOfPacket = true;
            // Build debug string (val)
            val =
                "${byteArrayToHex(responseBytes)}, $nextPacketIndex, ..., $frameLen";

            // Replicate Array.Copy(responeBytes, nextpacketindex + 3, responseArray, 0, framelen);
            dataArray = responseBytes.sublist(
              nextPacketIndex + 3,
              nextPacketIndex + 3 + frameLen,
            );
          }
        } else {
          status = "GENERALERROR_INVALIDRESPFROMDONGLE";
          firstposdongleackreceived = false;
          endOfPacket = true;
        }
      }
    } catch (ex, stack) {
      dataArray = null;
      status = "$val\n\n${ex.toString()}\n\n${stack.toString()}";
    }

    return {"dataArray": dataArray, "status": status};
  }

  static Map<String, dynamic> checkResponseWithChannel(
    Uint8List pidBytesResponse,
    Uint8List requestBytes,
  ) {
    Uint8List? dataArray = pidBytesResponse;
    String status = "NOERROR";

    try {
      var responseBytes = pidBytesResponse;
      var request = requestBytes;
      String expectedFrame = "";
      String reqType = "";
      int nextPacketIndex = 0;
      bool endOfPacket = false;
      int frameLen = 0;

      // 1. Logic for CONFIGREQUEST based on request[3] (Channel offset)
      if (request[0] == 0x20) {
        reqType = "CONFIGREQUEST";
        switch (request[3]) {
          case 0x01: // Reset Dongle
          case 0x02: // Set Protocol
          case 0x04: // Set Transmit Header
          case 0x06: // Set Receive Header
          case 0x08: // Set Block length
          case 0x0A: // Set separation time
          case 0x0C: // Set Min time
          case 0x0E: // Set Max wait time
          case 0x10: // Periodic tester present
          case 0x11: // Stop periodic tester present
          case 0x12: // Pad transmit
          case 0x13: // Stop padding
          case 0x15: // BT name change
          case 0x17: // Set filters
            expectedFrame = "DONGLECONFIGACK";
            break;
          case 0x03: // Get Protocol
          case 0x05: // Get Transmit Header
          case 0x07: // Get Receive Header
          case 0x09: // Get Block length
          case 0x0B: // Get separation time
          case 0x0D: // Get Min time
          case 0x0F: // Get Max wait time
          case 0x14: // Get firmware version
            expectedFrame = "DONGLECONFIGRESPONSE";
            break;
        }
      } else if (request[0] == 0x40) {
        reqType = "DATAREQUEST";
        expectedFrame = "DONGLECONFIGACK";
      }

      nextPacketIndex = 0;
      endOfPacket = false;

      // 2. Main Parser Loop
      while (!endOfPacket) {
        // Range check to prevent out of bounds
        if (nextPacketIndex >= responseBytes.length) {
          endOfPacket = true;
          break;
        }

        // --- Dongle Response Header (0x20) ---
        if (responseBytes[nextPacketIndex] == 0x20) {
          frameLen = responseBytes[nextPacketIndex + 1];

          if (reqType == "CONFIGREQUEST") {
            endOfPacket = true;
            if (expectedFrame == "DONGLECONFIGRESPONSE") {
              // Copy from index 4
              dataArray = responseBytes.sublist(
                nextPacketIndex + 4,
                nextPacketIndex + 4 + frameLen,
              );
            }
          }
          // Positive Ack (0x01 for Channel variants)
          else if (responseBytes[nextPacketIndex + 1] == 0x01) {
            if (firstposdongleackreceived == true) {
              firstposdongleackreceived = false;
              endOfPacket = true;
              status = "NOERROR";
              developer.log(
                "------ Jugaad - Getting positive dongle ack frame second time -------",
              );
              break;
            }

            nextPacketIndex += 6;
            firstposdongleackreceived = true;

            if (nextPacketIndex < responseBytes.length) {
              endOfPacket = false;
            } else {
              status = "READAGAIN";
              endOfPacket = true;
              break;
            }
          }
          // Negative Dongle Ack
          else {
            endOfPacket = true;
            firstposdongleackreceived = false;
            switch (responseBytes[4]) {
              case 0x10:
                status = "DONGLEERROR_COMMANDNOTSUPPORTED";
                break;
              case 0x12:
                status = "DONGLEERROR_INPUTNOTSUPPORTED";
                break;
              case 0x13:
                status = "DONGLEERROR_INVALIDFORMAT";
                break;
              case 0x14:
                status = "DONGLEERROR_INVALIDOPERATION";
                break;
              case 0x15:
                status = "DONGLEERROR_CRCFAILURE";
                break;
              case 0x16:
                status = "DONGLEERROR_PROTOCOLNOTSET";
                break;
              case 0x33:
                status = "DONGLEERROR_SECURITYACCESSDENIED";
                break;
            }
          }
        }
        // --- ECU Timeout (0x40 0x00) ---
        else if (((responseBytes[nextPacketIndex] & 0xF0) == 0x40) &&
            (responseBytes[nextPacketIndex + 1] == 0x00)) {
          status = "ECUERROR_NORESPONSEFROMECU";
          endOfPacket = true;
          firstposdongleackreceived = false;
          break;
        }
        // --- ECU Data Frame (4X) ---
        else if (((responseBytes[nextPacketIndex] & 0xF0) == 0x40) ||
            halfActualRespons.isNotEmpty) {
          firstposdongleackreceived = false;

          // Compute msg length (mask 0x0F shift 8 + next byte)
          int msgLen =
              ((responseBytes[nextPacketIndex] & 0x0F) << 8) +
              responseBytes[nextPacketIndex + 1];
          frameLen = msgLen;

          if (halfActualRespons.isEmpty) {
            actualLenth = msgLen;
          }

          // Check for ECU Negative Response (7F at index 3 for Channel)
          if (responseBytes[nextPacketIndex + 3] == 0x7F) {
            if (responseBytes[nextPacketIndex + 5] == 0x78) {
              nextPacketIndex += 8;
              endOfPacket = false;
              if (nextPacketIndex > responseBytes.length - 1) {
                status = "READAGAIN";
                endOfPacket = true;
                break;
              }
            } else {
              endOfPacket = true;
              int nrc = responseBytes[nextPacketIndex + 5];
              // Map standard UDS NRC codes
              switch (nrc) {
                case 0x10:
                  status = "ECUERROR_GENERALREJECT";
                  break;
                case 0x11:
                  status = "ECUERROR_SERVICENOTSUPPORTED";
                  break;
                case 0x12:
                  status = "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
                  break;
                case 0x13:
                  status = "ECUERROR_INVALIDFORMAT";
                  break;
                case 0x14:
                  status = "ECUERROR_RESPONSETOOLONG";
                  break;
                case 0x21:
                  status = "ECUERROR_BUSYREPEATREQUEST";
                  break;
                case 0x22:
                  status = "ECUERROR_CONDITIONSNOTCORRECT";
                  break;
                case 0x24:
                  status = "ECUERROR_REQUESTSEQUENCEERROR";
                  break;
                case 0x31:
                  status = "ECUERROR_REQUESTOUTOFRANGE";
                  break;
                case 0x33:
                  status = "ECUERROR_SECURITYACCESSDENIED";
                  break;
                case 0x35:
                  status = "ECUERROR_INVALIDKEY";
                  break;
                case 0x36:
                  status = "ECUERROR_EXCEEDEDNUMBEROFATTEMPTS";
                  break;
                case 0x37:
                  status = "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED";
                  break;
                case 0x70:
                  status = "ECUERROR_UPLOADDOWNLOADNOTACCEPTED";
                  break;
                case 0x71:
                  status = "ECUERROR_TRANSFERDATASUSPENDED";
                  break;
                case 0x72:
                  status = "ECUERROR_GENERALPROGRAMMINGFAILURE";
                  break;
                case 0x73:
                  status = "ECUERROR_WRONGBLOCKSEQCOUNTER";
                  break;
                case 0x7E:
                  status = "ECUERROR_SUBFNNOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x7F:
                  status = "ECUERROR_SERVICENOTSUPPORTEDINACTIVESESSION";
                  break;
                case 0x81:
                  status = "ECUERROR_RPMTOOHIGH";
                  break;
                case 0x82:
                  status = "ECUERROR_RPMTOOLOW";
                  break;
                case 0x83:
                  status = "ECUERROR_ENGINEISRUNNING";
                  break;
                case 0x84:
                  status = "ECUERROR_ENGINEISNOTRUNNING";
                  break;
                case 0x85:
                  status = "ECUERROR_ENGINERUNTIMETOOLOW";
                  break;
                case 0x86:
                  status = "ECUERROR_TEMPTOOHIGH";
                  break;
                case 0x87:
                  status = "ECUERROR_TEMPTOOLOW";
                  break;
                case 0x88:
                  status = "ECUERROR_VEHSPEEDTOOHIGH";
                  break;
                case 0x89:
                  status = "ECUERROR_VEHSPEEDTOOLOW";
                  break;
                case 0x8A:
                  status = "ECUERROR_THROTTLETOOHIGH";
                  break;
                case 0x8B:
                  status = "ECUERROR_THROTTLETOOLOW";
                  break;
                case 0x8C:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINNEUTRAL";
                  break;
                case 0x8D:
                  status = "ECUERROR_TRANSMISSIONRANGENOTINGEAR";
                  break;
                case 0x8F:
                  status = "ECUERROR_BRKPEDALNOTPRESSED";
                  break;
                case 0x90:
                  status = "ECUERROR_SHIFTERLEVERNOTINPARK";
                  break;
                case 0x91:
                  status = "ECUERROR_TRQCONVERTERCLUTCHLOCKED";
                  break;
                case 0x92:
                  status = "ECUERROR_VOLTAGETOOHIGH";
                  break;
                case 0x93:
                  status = "ECUERROR_VOLTAGETOOLOW";
                  break;
              }
            }
          }
          // --- Positive ECU Response (Data Extraction) ---
          else {
            endOfPacket = true;

            val =
                "${byteArrayToHex(responseBytes)}, ${nextPacketIndex + 3}, ..., $frameLen";
            developer.log("Array Copy Detail: $val");

            if (halfActualRespons.isNotEmpty) {
              halfActualRespons += byteArrayToHex(responseBytes);
              responseBytes = hexToUint8List(halfActualRespons);
              frameLen = actualLenth;
            }

            // Check if buffer is complete (5 bytes header/checksum logic)
            if ((responseBytes.length - 5) < responseBytes[1]) {
              status = "READAGAIN";
              halfActualRespons = byteArrayToHex(responseBytes);
            } else {
              if (halfActualRespons.isNotEmpty) {
                halfActualRespons = "";
                actualLenth = 0;
              }
              status = "NOERROR";
              // Copy data starting from index 3
              dataArray = responseBytes.sublist(
                nextPacketIndex + 3,
                nextPacketIndex + 3 + frameLen,
              );
            }
          }
        } else {
          status = "GENERALERROR_INVALIDRESPFROMDONGLE";
          firstposdongleackreceived = false;
          endOfPacket = true;
        }
      }
    } catch (ex, stack) {
      dataArray = null;
      status = "$val\n\n${ex.toString()}\n\n${stack.toString()}";
    }

    return {"dataArray": dataArray, "status": status};
  }

  static Map<String, dynamic> checkResponseRP1210(
    Uint8List pidBytesResponse,
    Uint8List requestBytes,
  ) {
    Uint8List? dataArray = pidBytesResponse;
    String status = "NOERROR";

    try {
      var responseBytes = pidBytesResponse;
      var request = requestBytes;
      int nextPacketIndex = 0;
      bool endOfPacket = false;

      // Parser Loop
      while (!endOfPacket) {
        // Range check to prevent out of bounds
        if (nextPacketIndex >= responseBytes.length) {
          endOfPacket = true;
          break;
        }

        // 1. Check for Negative Response SID (0x7F)
        if (responseBytes[nextPacketIndex] == 0x7F) {
          // Check for NRC 0x78 (Response Pending)
          if (responseBytes[nextPacketIndex + 2] == 0x78) {
            /* read next packet */
            nextPacketIndex += 7; // Standard RP1210 skip for pending frame
            endOfPacket = false;

            if (nextPacketIndex > responseBytes.length - 1) {
              status = "READAGAIN";
              endOfPacket = true;
              break;
            }
          } else {
            // Permanent Negative Response
            endOfPacket = true;
            int nrc = responseBytes[nextPacketIndex + 2];

            // Map ECU Negative Response Codes
            status = _mapStandardNRC(nrc);

            // dataArray = new byte[3]; Array.Copy(responeBytes, nextpacketindex, dataArray, 0, 3);
            dataArray = responseBytes.sublist(
              nextPacketIndex,
              nextPacketIndex + 3,
            );
          }
        } else {
          // 2. Positive Response Validation (SID + 0x40)
          int respFirstByte = responseBytes[nextPacketIndex];
          int reqFirstByte = request[0];

          if (respFirstByte == (reqFirstByte + 0x40)) {
            status = "NOERROR";
            endOfPacket = true;
            // For RP1210, we usually return the whole buffer as dataArray
            dataArray = responseBytes;
          } else {
            // Handle specific error byte 0x01
            if (respFirstByte == 0x01) {
              status = "ECUERROR_NORESPONSEFROMECU";
            } else {
              // Generic fallback for mismatched SID
              status = "READAGAIN";
            }
            endOfPacket = true;
          }
        }
      }
    } catch (ex, stack) {
      dataArray = null;
      status = "\n${ex.toString()}\n\n${stack.toString()}";
    }

    return {"dataArray": dataArray, "status": status};
  }

  /// Internal helper to map UDS/KWP Negative Response Codes
  static String _mapStandardNRC(int nrc) {
    switch (nrc) {
      case 0x10:
        return "ECUERROR_GENERALREJECT";
      case 0x11:
        return "ECUERROR_SERVICENOTSUPPORTED";
      case 0x12:
        return "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
      case 0x13:
        return "ECUERROR_INVALIDFORMAT";
      case 0x14:
        return "ECUERROR_RESPONSETOOLONG";
      case 0x21:
        return "ECUERROR_BUSYREPEATREQUEST";
      case 0x22:
        return "ECUERROR_CONDITIONSNOTCORRECT";
      case 0x24:
        return "ECUERROR_REQUESTSEQUENCEERROR";
      case 0x31:
        return "ECUERROR_REQUESTOUTOFRANGE";
      case 0x33:
        return "ECUERROR_SECURITYACCESSDENIED";
      case 0x35:
        return "ECUERROR_INVALIDKEY";
      case 0x36:
        return "ECUERROR_EXCEEDEDNUMBEROFATTEMPTS";
      case 0x37:
        return "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED";
      case 0x70:
        return "ECUERROR_UPLOADDOWNLOADNOTACCEPTED";
      case 0x71:
        return "ECUERROR_TRANSFERDATASUSPENDED";
      case 0x72:
        return "ECUERROR_GENERALPROGRAMMINGFAILURE";
      case 0x73:
        return "ECUERROR_WRONGBLOCKSEQCOUNTER";
      case 0x7E:
        return "ECUERROR_SUBFNNOTSUPPORTEDINACTIVESESSION";
      case 0x7F:
        return "ECUERROR_SERVICENOTSUPPORTEDINACTIVESESSION";
      case 0x81:
        return "ECUERROR_RPMTOOHIGH";
      case 0x82:
        return "ECUERROR_RPMTOOLOW";
      case 0x83:
        return "ECUERROR_ENGINEISRUNNING";
      case 0x84:
        return "ECUERROR_ENGINEISNOTRUNNING";
      case 0x85:
        return "ECUERROR_ENGINERUNTIMETOOLOW";
      case 0x86:
        return "ECUERROR_TEMPTOOHIGH";
      case 0x87:
        return "ECUERROR_TEMPTOOLOW";
      case 0x88:
        return "ECUERROR_VEHSPEEDTOOHIGH";
      case 0x89:
        return "ECUERROR_VEHSPEEDTOOLOW";
      case 0x8A:
        return "ECUERROR_THROTTLETOOHIGH";
      case 0x8B:
        return "ECUERROR_THROTTLETOOLOW";
      case 0x8C:
        return "ECUERROR_TRANSMISSIONRANGENOTINNEUTRAL";
      case 0x8D:
        return "ECUERROR_TRANSMISSIONRANGENOTINGEAR";
      case 0x8F:
        return "ECUERROR_BRKPEDALNOTPRESSED";
      case 0x90:
        return "ECUERROR_SHIFTERLEVERNOTINPARK";
      case 0x91:
        return "ECUERROR_TRQCONVERTERCLUTCHLOCKED";
      case 0x92:
        return "ECUERROR_VOLTAGETOOHIGH";
      case 0x93:
        return "ECUERROR_VOLTAGETOOLOW";
      default:
        return "ECUERROR_UNKNOWN_NRC_${nrc.toRadixString(16)}";
    }
  }
}
