import 'dart:typed_data';

import 'package:ap_dongle_comm/utils/model/responseArrayStatusModel.dart';

class ResponseArrayDecoding {
  static bool firstposdongleackreceived = false;
  static String val = "";
  static String halfActualRespons = "";
  static int actualLenth = 0;

//   static (Uint8List?, String) checkResponse(Uint8List pidBytesResponse, Uint8List requestBytes) {
//     try {
//       var responeBytes = pidBytesResponse;
//       var request = requestBytes;
//       String expectedframe = "";
//       String reqtype = "";
//       int nextpacketindex = 0;
//       Uint8List? dataArray = pidBytesResponse;
//       String status = "NOERROR";
//       bool endofpacket = false;
//       int framelen = 0;
//       if (request[0] == 0x20) {
//         reqtype = "CONFIGREQUEST";
//         switch (request[2]) {
//           case 0x01: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x02: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x03: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x04: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x05: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x06: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x07: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x08: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x09: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x0A: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x0B: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x0C: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x0D: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x0E: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x0F: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x10: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x11: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x12: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x13: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x14: expectedframe = "DONGLECONFIGRESPONSE"; break;
//           case 0x15: expectedframe = "DONGLECONFIGACK"; break;
//           case 0x17: expectedframe = "DONGLECONFIGACK"; break;
//         }
//       } else if (request[0] == 0x40) {
//         reqtype = "DATAREQUEST";
//         expectedframe = "DONGLECONFIGACK";
//       }

//       nextpacketindex = 0;
//       endofpacket = false;

//       // 2. Parser Loop
//       while (endofpacket == false) {
//         if (responeBytes[nextpacketindex] == 0x20) {
//           framelen = responeBytes[nextpacketindex + 1];

//           if (reqtype == "CONFIGREQUEST") {
//             endofpacket = true;
//             if (expectedframe == "DONGLECONFIGRESPONSE") {
//               int length = framelen - 2;
//               dataArray = responeBytes.sublist(nextpacketindex + 3, nextpacketindex + 3 + length);
//               endofpacket = true;
//             }
//           } 
//           else if (responeBytes[nextpacketindex + 1] == 0x03) {
//             if (firstposdongleackreceived == true) {
//               firstposdongleackreceived = false;
//               endofpacket = true;
//               status = "NOERROR";
//               break; // Equivalent to C# break;
//             }

//             nextpacketindex += 5;
//             firstposdongleackreceived = true;

//             if (nextpacketindex < responeBytes.length) {
//               endofpacket = false;
//             } else {
//               status = "READAGAIN";
//               endofpacket = true;
//               break;
//             }
//           } 
//           else {
//             endofpacket = true;
//             firstposdongleackreceived = false;
//             switch (responeBytes[nextpacketindex + 3]) {
//               case 0x10: status = "DONGLEERROR_COMMANDNOTSUPPORTED"; break;
//               case 0x12: status = "DONGLEERROR_INPUTNOTSUPPORTED"; break;
//               case 0x13: status = "SENDAGAIN"; break;
//               case 0x14: status = "DONGLEERROR_INVALIDOPERATION"; break;
//               case 0x15: status = "SENDAGAIN"; break;
//               case 0x16: status = "DONGLEERROR_PROTOCOLNOTSET"; break;
//               case 0x33: status = "DONGLEERROR_SECURITYACCESSDENIED"; break;
//             }
//             status = "SENDAGAIN"; 
//           }
//         } 
//         // 3. ECU No Response Logic
//         else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) && (responeBytes[nextpacketindex + 1] == 0x02)) {
//           status = "ECUERROR_NORESPONSEFROMECU";
//           endofpacket = true;
//           firstposdongleackreceived = false;
//           break;
//         } 
//         // 4. ECU Data Frame Logic
//         else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) || halfActualRespons.isNotEmpty) {
//           firstposdongleackreceived = false;
//           var msglen = ((responeBytes[nextpacketindex] & 0x0F) << 8) + responeBytes[nextpacketindex + 1];
//           framelen = msglen;

//           if (halfActualRespons.isEmpty) {
//             actualLenth = msglen;
//           }

//           if (responeBytes[nextpacketindex + 2] == 0x7F) {
//             if (responeBytes[nextpacketindex + 4] == 0x78) {
//               nextpacketindex += 7;
//               endofpacket = false;
//               if (nextpacketindex > responeBytes.length - 1) {
//                 status = "READAGAIN";
//                 endofpacket = true;
//                 break;
//               }
//             } else {
//               endofpacket = true;
//               int errorCode = responeBytes[nextpacketindex + 4];
//               status = _getEcuErrorStatus(errorCode);
//             }
//           } else {
//             // Reassembly Logic
//             if (halfActualRespons.isNotEmpty) {
//               halfActualRespons += _byteArrayToHex(responeBytes);
//               responeBytes = _hexToByteArray(halfActualRespons);
//               framelen = actualLenth;
//             }

//             if ((responeBytes.length - 2) < responeBytes[1]) {
//               status = "READAGAIN";
//               halfActualRespons = _byteArrayToHex(responeBytes);
//               endofpacket = true;
//             } else {
//               if (halfActualRespons.isNotEmpty) {
//                 halfActualRespons = "";
//                 actualLenth = 0;
//               }
//               status = "NOERROR";
//               dataArray = responeBytes.sublist(nextpacketindex + 2, nextpacketindex + framelen);
//               endofpacket = true;
//             }
//           }
//         } else {
//           status = "GENERALERROR_INVALIDRESPFROMDONGLE";
//           firstposdongleackreceived = false;
//           endofpacket = true;
//         }
//       }
//       return (dataArray, status);
//     } catch (ex) {
//       return (null, "EXCEPTION: $ex");
//     }
//   }
// static String _getEcuErrorStatus(int code) {
//     switch (code) {
//       case 0x10: return "ECUERROR_GENERALREJECT";
//       case 0x11: return "ECUERROR_SERVICENOTSUPPORTED";
//       case 0x12: return "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
//       case 0x13: return "ECUERROR_INVALIDFORMAT";
//       case 0x14: return "ECUERROR_RESPONSETOOLONG";
//       case 0x21: return "ECUERROR_BUSYREPEATREQUEST";
//       case 0x22: return "ECUERROR_CONDITIONSNOTCORRECT";
//       case 0x24: return "ECUERROR_REQUESTSEQUENCEERROR";
//       case 0x31: return "ECUERROR_REQUESTOUTOFRANGE";
//       case 0x33: return "ECUERROR_SECURITYACCESSDENIED";
//       case 0x35: return "ECUERROR_INVALIDKEY";
//       case 0x36: return "ECUERROR_EXCEEDEDNUMBEROFATTEMPTS";
//       case 0x37: return "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED";
//       case 0x72: return "ECUERROR_GENERALPROGRAMMINGFAILURE";
//       case 0x92: return "ECUERROR_VOLTAGETOOHIGH";
//       case 0x93: return "ECUERROR_VOLTAGETOOLOW";
//       default: return "ECU_UNKNOWN_ERROR";
//     }
//   }

static String halfActualResponse = "";
static int actualLength = 0;
static bool firstPosDongleAckReceived = false;

static ResponseArrayStatus checkResponse(
  Uint8List pidBytesResponse,
  Uint8List requestBytes,
) {
  try {
    Uint8List responseBytes = pidBytesResponse;
    Uint8List request = requestBytes;

    Uint8List dataArray = pidBytesResponse;
    String status = "NOERROR";

    String expectedFrame = "";
    String reqType = "";

    int nextPacketIndex = 0;
    bool endOfPacket = false;
    int frameLen = 0;

    // ---------------- REQUEST TYPE ----------------

    if (request[0] == 0x20) {
      reqType = "CONFIGREQUEST";

      switch (request[2]) {
        case 0x03:
        case 0x05:
        case 0x07:
        case 0x09:
        case 0x0B:
        case 0x0D:
        case 0x0F:
        case 0x14:
          expectedFrame = "DONGLECONFIGRESPONSE";
          break;

        default:
          expectedFrame = "DONGLECONFIGACK";
      }
    } else if (request[0] == 0x40) {
      reqType = "DATAREQUEST";
      expectedFrame = "DONGLECONFIGACK";
    }

    // ---------------- PARSER LOOP ----------------

    while (!endOfPacket) {
      if (responseBytes[nextPacketIndex] == 0x20) {
        frameLen = responseBytes[nextPacketIndex + 1];

        // CONFIG REQUEST
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

        // POSITIVE DONGLE ACK
        else if (responseBytes[nextPacketIndex + 1] == 0x03) {
          if (firstPosDongleAckReceived) {
            firstPosDongleAckReceived = false;
            endOfPacket = true;
            status = "NOERROR";
            break;
          }

          nextPacketIndex += 5;
          firstPosDongleAckReceived = true;

          if (nextPacketIndex < responseBytes.length) {
            endOfPacket = false;
          } else {
            status = "READAGAIN";
            endOfPacket = true;
            break;
          }
        }

        // NEGATIVE DONGLE ACK
        else {
          endOfPacket = true;
          firstPosDongleAckReceived = false;
          status = "SENDAGAIN";
        }
      }

      // ECU NO RESPONSE
      else if ((responseBytes[nextPacketIndex] & 0xF0) == 0x40 &&
          responseBytes[nextPacketIndex + 1] == 0x02) {
        status = "ECUERROR_NORESPONSEFROMECU";
        endOfPacket = true;
        firstPosDongleAckReceived = false;
      }

      // DATA FRAME (4x)
      else if ((responseBytes[nextPacketIndex] & 0xF0) == 0x40 ||
          halfActualResponse.isNotEmpty) {
        firstPosDongleAckReceived = false;

        int msgLen = ((responseBytes[nextPacketIndex] & 0x0F) << 8) +
            responseBytes[nextPacketIndex + 1];

        frameLen = msgLen;

        if (halfActualResponse.isEmpty) {
          actualLength = msgLen;
        }

        // ECU NEGATIVE RESPONSE
        if (responseBytes[nextPacketIndex + 2] == 0x7F) {
          if (responseBytes[nextPacketIndex + 4] == 0x78) {
            nextPacketIndex += 7;
            endOfPacket = false;

            if (nextPacketIndex > responseBytes.length - 1) {
              status = "READAGAIN";
              endOfPacket = true;
            }
          } else {
            endOfPacket = true;
            status = _mapEcuError(responseBytes[nextPacketIndex + 4]);
          }
        }

        // ECU POSITIVE RESPONSE
        else {
          endOfPacket = true;

          int length = frameLen - 2;

          if ((responseBytes.length - 2) < responseBytes[1]) {
            status = "READAGAIN";
            halfActualResponse = _byteToHex(responseBytes);
          } else {
            if (halfActualResponse.isNotEmpty) {
              halfActualResponse = "";
              actualLength = 0;
            }

            status = "NOERROR";

            dataArray = responseBytes.sublist(
              nextPacketIndex + 2,
              nextPacketIndex + 2 + length,
            );
          }
        }
      }

      else {
        status = "GENERALERROR_INVALIDRESPFROMDONGLE";
        firstPosDongleAckReceived = false;
        endOfPacket = true;
      }
    }

    return ResponseArrayStatus(
      ecuResponse: pidBytesResponse,
      ecuResponseStatus: status,
      actualDataBytes: dataArray,
    );
  } catch (e) {
    return ResponseArrayStatus(
      ecuResponse: null,
      ecuResponseStatus: e.toString(),
      actualDataBytes: null,
    );
  }
}

static String _mapEcuError(int code) {
  switch (code) {
    case 0x10:
      return "ECUERROR_GENERALREJECT";
    case 0x11:
      return "ECUERROR_SERVICENOTSUPPORTED";
    case 0x12:
      return "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
    case 0x13:
      return "ECUERROR_INVALIDFORMAT";
    case 0x21:
      return "ECUERROR_BUSYREPEATREQUEST";
    case 0x22:
      return "ECUERROR_CONDITIONSNOTCORRECT";
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
    case 0x7E:
      return "ECUERROR_SUBFNNOTSUPPORTEDINACTIVESESSION";
    case 0x7F:
      return "ECUERROR_SERVICENOTSUPPORTEDINACTIVESESSION";
    case 0x92:
      return "ECUERROR_VOLTAGETOOHIGH";
    case 0x93:
      return "ECUERROR_VOLTAGETOOLOW";
    default:
      return "ECUERROR_UNKNOWN";
  }
}

  // // Conversion Helpers
  static String _byteToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  // static Uint8List _hexToByteArray(String hex) {
  //   hex = hex.replaceAll(" ", "");
  //   if (hex.length % 2 != 0) hex = "0$hex";
  //   var result = Uint8List(hex.length ~/ 2);
  //   for (var i = 0; i < hex.length; i += 2) {
  //     result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  //   }
  //   return result;
  // }
  static (Uint8List?, String) checkResponseIVN(
      Uint8List pidBytesResponse, Uint8List requestBytes, String s) {
    try {
      var responeBytes = pidBytesResponse;
      var request = requestBytes;
      String expectedframe = "";
      String reqtype = "";
      int nextpacketindex = 0;
      Uint8List? dataArray;
      String status = "NOERROR";
      bool endofpacket = false;
      int framelen = 0;

      // 1. Identify Request Type
      if (request[0] == 0x20) {
        // reqtype = "CONFIGREQUEST"; (Commented out as in your .NET code)
        switch (request[2]) {
          case 0x01: expectedframe = "DONGLECONFIGACK"; break;
          case 0x02: expectedframe = "DONGLECONFIGACK"; break;
          case 0x03: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x04: expectedframe = "DONGLECONFIGACK"; break;
          case 0x05: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x06: expectedframe = "DONGLECONFIGACK"; break;
          case 0x07: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x08: expectedframe = "DONGLECONFIGACK"; break;
          case 0x09: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x0A: expectedframe = "DONGLECONFIGACK"; break;
          case 0x0B: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x0C: expectedframe = "DONGLECONFIGACK"; break;
          case 0x0D: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x0E: expectedframe = "DONGLECONFIGACK"; break;
          case 0x0F: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x10: expectedframe = "DONGLECONFIGACK"; break;
          case 0x11: expectedframe = "DONGLECONFIGACK"; break;
          case 0x12: expectedframe = "DONGLECONFIGACK"; break;
          case 0x13: expectedframe = "DONGLECONFIGACK"; break;
          case 0x14: expectedframe = "DONGLECONFIGRESPONSE"; break;
          case 0x15: expectedframe = "DONGLECONFIGACK"; break;
          case 0x17: expectedframe = "DONGLECONFIGACK"; break;
        }
      } else if (request[0] == 0x40) {
        reqtype = "DATAREQUEST";
        expectedframe = "DONGLECONFIGACK";
      }

      nextpacketindex = 0;
      endofpacket = false;

      // 2. Parser Loop
      while (endofpacket == false) {
        if (responeBytes[nextpacketindex] == 0x20) {
          framelen = responeBytes[nextpacketindex + 1];

          if (reqtype == "CONFIGREQUEST") {
            endofpacket = true;
            if (expectedframe == "DONGLECONFIGRESPONSE") {
              int length = framelen - 2;
              // Equivalent to Array.Copy
              dataArray = responeBytes.sublist(nextpacketindex + 3, nextpacketindex + 3 + length);
              endofpacket = true;
            }
          } 
          else if (responeBytes[nextpacketindex + 1] == 0x03) {
            if (firstposdongleackreceived == true) {
              firstposdongleackreceived = false;
              endofpacket = true;
              status = "NOERROR";
             print("------ Jugaad - Getting positive dongle ack frame from dongle for second time -------");
              break;
            }

            nextpacketindex += 5;
            firstposdongleackreceived = true;

            if (nextpacketindex < responeBytes.length) {
              endofpacket = false;
            } else {
              status = "READAGAIN";
              endofpacket = true;
              break;
            }
          } 
          else {
            // Negative ACK from dongle
            endofpacket = true;
            firstposdongleackreceived = false;
            switch (responeBytes[nextpacketindex + 3]) {
              case 0x10: status = "DONGLEERROR_COMMANDNOTSUPPORTED"; break;
              case 0x12: status = "DONGLEERROR_INPUTNOTSUPPORTED"; break;
              case 0x13: status = "DONGLEERROR_INVALIDFORMAT"; break;
              case 0x14: status = "DONGLEERROR_INVALIDOPERATION"; break;
              case 0x15: status = "SENDAGAIN"; break; // CRC Failure
              case 0x16: status = "DONGLEERROR_PROTOCOLNOTSET"; break;
              case 0x33: status = "DONGLEERROR_SECURITYACCESSDENIED"; break;
            }
            status = "SENDAGAIN"; 
          }
        } 
        // 3. ECU No Response Logic
        else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) && (responeBytes[nextpacketindex + 1] == 0x02)) {
          status = "ECUERROR_NORESPONSEFROMECU";
          endofpacket = true;
          firstposdongleackreceived = false;
          break;
        } 
        // 4. ECU Data Frame Logic
        else if ((responeBytes[nextpacketindex] & 0xF0) == 0x40) {
          firstposdongleackreceived = false;
          var msglen = ((responeBytes[nextpacketindex] & 0x0F) << 8) + responeBytes[nextpacketindex + 1];
          framelen = msglen;

          if (responeBytes[nextpacketindex + 2] == 0x7F) {
            if (responeBytes[nextpacketindex + 4] == 0x78) {
              nextpacketindex += 7;
              endofpacket = false;
              if (nextpacketindex > responeBytes.length - 1) {
                status = "READAGAIN";
                endofpacket = true;
                break;
              }
            } else {
              endofpacket = true;
              int errorCode = responeBytes[nextpacketindex + 4];
              status = _mapEcuError(errorCode);
            }
          } else {
            // Positive response from dongle/ECU
            endofpacket = true;
            int length = framelen - 2;
            
            // Debug string like your 'val' variable
            val = "${_byteArrayToString(responeBytes)}, $nextpacketindex, ${length}, $framelen";
            
            dataArray = responeBytes.sublist(nextpacketindex + 2, nextpacketindex + 2 + length);
          }
        } else {
          status = "GENERALERROR_INVALIDRESPFROMDONGLE";
          firstposdongleackreceived = false;
          endofpacket = true;
        }
      }
      return (dataArray, status);
    } catch (ex, stack) {
      return (null, "$val\n\n${ex.toString()}\n\n$stack");
    }
  }
/// Main method to check response (Equivalent to CheckResponseWithChannel)
  // static (Uint8List?, String) CheckResponseWithChannel(Uint8List pidBytesResponse, Uint8List requestBytes) {
  //   try {
  //     Uint8List responeBytes = pidBytesResponse;
  //     Uint8List request = requestBytes;
  //     String expectedframe = "";
  //     String reqtype = "";
  //     int nextpacketindex = 0;
  //     Uint8List? dataArray = pidBytesResponse; // Default assignment
  //     String status = "NOERROR";
  //     bool endofpacket = false;
  //     int framelen = 0;

  //     // 1. Identify Request Type
  //     if (request[0] == 0x20) {
  //       reqtype = "CONFIGREQUEST";
  //       // Note: Using request[3] to match your original C# logic index
  //       switch (request[3]) {
  //         case 0x01: case 0x02: case 0x04: case 0x06: case 0x08:
  //         case 0x0A: case 0x0C: case 0x0E: case 0x10: case 0x11:
  //         case 0x12: case 0x13: case 0x15: case 0x17:
  //           expectedframe = "DONGLECONFIGACK";
  //           break;
  //         case 0x03: case 0x05: case 0x07: case 0x09: case 0x0B:
  //         case 0x0D: case 0x0F: case 0x14:
  //           expectedframe = "DONGLECONFIGRESPONSE";
  //           break;
  //       }
  //     } else if (request[0] == 0x40) {
  //       reqtype = "DATAREQUEST";
  //       expectedframe = "DONGLECONFIGACK";
  //     }

  //     // 2. Parser Loop
  //     while (!endofpacket) {
  //       // Bounds check
  //       if (nextpacketindex >= responeBytes.length) {
  //         status = "READAGAIN";
  //         break;
  //       }

  //       // --- Dongle Configuration Response (0x20) ---
  //       if (responeBytes[nextpacketindex] == 0x20) {
  //         framelen = responeBytes[nextpacketindex + 1];

  //         if (reqtype == "CONFIGREQUEST") {
  //           endofpacket = true;
  //           if (expectedframe == "DONGLECONFIGRESPONSE") {
  //             // Extract data based on frame length
  //             dataArray = responeBytes.sublist(nextpacketindex + 4, nextpacketindex + 4 + framelen);
  //           }
  //         } 
  //         else if (responeBytes[nextpacketindex + 1] == 0x01) {
  //           // Handle "Jugaad" / Positive Ack
  //           if (firstposdongleackreceived) {
  //             firstposdongleackreceived = false;
  //             endofpacket = true;
  //             status = "NOERROR";
  //             break;
  //           }

  //           nextpacketindex += 6;
  //           firstposdongleackreceived = true;

  //           if (nextpacketindex < responeBytes.length) {
  //             endofpacket = false;
  //           } else {
  //             status = "READAGAIN";
  //             endofpacket = true;
  //             break;
  //           }
  //         } else {
  //           // Dongle Negative Ack
  //           status = getDongleError(responeBytes[nextpacketindex + 4]);
  //           firstposdongleackreceived = false;
  //           endofpacket = true;
  //         }
  //       } 
        
  //       // --- ECU No Response (0x40 0x00) ---
  //       else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) && (responeBytes[nextpacketindex + 1] == 0x00)) {
  //         status = "ECUERROR_NORESPONSEFROMECU";
  //         endofpacket = true;
  //         firstposdongleackreceived = false;
  //         break;
  //       } 

  //       // --- ECU Data Frame / Reassembly Logic ---
  //       else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) || halfActualRespons.isNotEmpty) {
  //         firstposdongleackreceived = false;
          
  //         int msglen = ((responeBytes[nextpacketindex] & 0x0F) << 8) + responeBytes[nextpacketindex + 1];
  //         framelen = msglen;

  //         if (halfActualRespons.isEmpty) {
  //           actualLenth = msglen;
  //         }

  //         // Check for Negative Response (7F)
  //         if (responeBytes[nextpacketindex + 3] == 0x7F) {
  //           if (responeBytes[nextpacketindex + 5] == 0x78) {
  //             // Response Pending - Skip and continue
  //             nextpacketindex += 8;
  //             if (nextpacketindex >= responeBytes.length) {
  //               status = "READAGAIN";
  //               endofpacket = true;
  //               break;
  //             }
  //           } else {
  //             status = _getEcuErrorStatus(responeBytes[nextpacketindex + 5]);
  //             endofpacket = true;
  //           }
  //         } else {
  //           // Successful Data Extraction & Reassembly
  //           if (halfActualRespons.isNotEmpty) {
  //             halfActualRespons += _byteArrayToHex(responeBytes);
  //             responeBytes = _hexToByteArray(halfActualRespons);
  //             framelen = actualLenth;
  //           }

  //           // Check if full packet received
  //           if ((responeBytes.length - 5) < responeBytes[1]) {
  //             status = "READAGAIN";
  //             halfActualRespons = _byteArrayToHex(responeBytes);
  //             endofpacket = true;
  //           } else {
  //             // Full packet received
  //             if (halfActualRespons.isNotEmpty) {
  //               halfActualRespons = "";
  //               actualLenth = 0;
  //             }
  //             status = "NOERROR";
  //             dataArray = responeBytes.sublist(nextpacketindex + 3, nextpacketindex + 3 + framelen);
  //             endofpacket = true;
  //           }
  //         }
  //       } else {
  //         status = "GENERALERROR_INVALIDRESPFROMDONGLE";
  //         firstposdongleackreceived = false;
  //         endofpacket = true;
  //       }
  //     }
  //     return (dataArray, status);
  //   } catch (ex, stack) {
  //     return (null, "EXCEPTION: $ex\n$stack");
  //   }
  // }

  static (Uint8List?, String) CheckResponseWithChannel(Uint8List pidBytesResponse, Uint8List requestBytes) {
  try {
    Uint8List responeBytes = pidBytesResponse;
    Uint8List request = requestBytes;
    String expectedframe = "";
    String reqtype = "";
    int nextpacketindex = 0;
    Uint8List? dataArray = pidBytesResponse; 
    String status = "NOERROR";
    bool endofpacket = false;
    int framelen = 0;

    // 1. Identify Request Type
    if (request.isNotEmpty && request[0] == 0x20) {
      reqtype = "CONFIGREQUEST";
      if (request.length > 3) {
        switch (request[3]) {
          case 0x01: case 0x02: case 0x04: case 0x06: case 0x08:
          case 0x0A: case 0x0C: case 0x0E: case 0x10: case 0x11:
          case 0x12: case 0x13: case 0x15: case 0x17:
            expectedframe = "DONGLECONFIGACK";
            break;
          case 0x03: case 0x05: case 0x07: case 0x09: case 0x0B:
          case 0x0D: case 0x0F: case 0x14:
            expectedframe = "DONGLECONFIGRESPONSE";
            break;
        }
      }
    } else if (request.isNotEmpty && request[0] == 0x40) {
      reqtype = "DATAREQUEST";
      expectedframe = "DONGLECONFIGACK";
    }

    // 2. Parser Loop
    while (!endofpacket) {
      if (nextpacketindex >= responeBytes.length) {
        status = "READAGAIN";
        break;
      }

      // --- Dongle Configuration Response (0x20) ---
      if (responeBytes[nextpacketindex] == 0x20) {
        if (responeBytes.length < nextpacketindex + 5) {
           status = "READAGAIN"; break;
        }
        
        framelen = responeBytes[nextpacketindex + 1];

        if (reqtype == "CONFIGREQUEST") {
          endofpacket = true;
          if (expectedframe == "DONGLECONFIGRESPONSE") {
            // Offset +4: [Header][Len][ID][Status] -> [Data Starts Here]
            dataArray = responeBytes.sublist(nextpacketindex + 4, nextpacketindex + 4 + framelen);
          }
        } 
        else if (responeBytes[nextpacketindex + 1] == 0x01) {
          // Positive ACK logic
          if (firstposdongleackreceived) {
            firstposdongleackreceived = false;
            endofpacket = true;
            status = "NOERROR";
            break;
          }
          nextpacketindex += 6;
          firstposdongleackreceived = true;
          if (nextpacketindex >= responeBytes.length) {
            status = "READAGAIN";
            endofpacket = true;
          }
        } else {
          // Dongle Negative Ack (e.g., CRC error or Buffer full)
          status = getDongleError(responeBytes[nextpacketindex + 4]);
          firstposdongleackreceived = false;
          endofpacket = true;
        }
      } 
      
      // --- ECU No Response (0x40 0x00) ---
      else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) && 
               (responeBytes.length > nextpacketindex + 1 && responeBytes[nextpacketindex + 1] == 0x00)) {
        status = "ECUERROR_NORESPONSEFROMECU";
        endofpacket = true;
        firstposdongleackreceived = false;
        break;
      } 

      // --- ECU Data Frame (0x4X) ---
      else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) || halfActualRespons.isNotEmpty) {
        firstposdongleackreceived = false;
        
        // Calculate UDS message length from 40 header
        int msglen = ((responeBytes[nextpacketindex] & 0x0F) << 8) + responeBytes[nextpacketindex + 1];
        framelen = msglen;

        if (halfActualRespons.isEmpty) {
          actualLenth = msglen;
        }

        // Channel ID Offset: Data starts at index 3 if no ChannelID, index 4 if ChannelID used
        // Your logic uses index + 3, which assumes NO channel byte in response
        int dataStartOffset = nextpacketindex + 3; 

        // Check for UDS Negative Response (7F)
        if (responeBytes.length > dataStartOffset + 2 && responeBytes[dataStartOffset] == 0x7F) {
          if (responeBytes[dataStartOffset + 2] == 0x78) {
            // NRC 78: Response Pending. Skip 40 header + 2 bytes CRC and look for more
            nextpacketindex += (msglen + 4); 
            status = "READAGAIN";
            if (nextpacketindex >= responeBytes.length) break;
          } else {
            status = _mapEcuError(responeBytes[dataStartOffset + 2]);
            endofpacket = true;
          }
        } else {
          // Data Reassembly (Multi-packet support)
          if (halfActualRespons.isNotEmpty) {
            // Append and convert
            String hexPart = responeBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            halfActualRespons += hexPart;
            responeBytes = Uint8List.fromList(
                RegExp(r'.{1,2}').allMatches(halfActualRespons).map((m) => int.parse(m.group(0)!, radix: 16)).toList()
            );
            framelen = actualLenth;
          }

          // Header (2) + Data (framelen) + CRC (2)
          if (responeBytes.length < (framelen + 4)) {
            status = "READAGAIN";
            halfActualRespons = responeBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            endofpacket = true;
          } else {
            halfActualRespons = "";
            actualLenth = 0;
            status = "NOERROR";
            dataArray = responeBytes.sublist(dataStartOffset, dataStartOffset + framelen);
            endofpacket = true;
          }
        }
      } else {
        status = "GENERALERROR_INVALIDRESPFROMDONGLE";
        endofpacket = true;
      }
    }
    return (dataArray, status);
  } catch (ex) {
    return (null, "EXCEPTION: $ex");
  }
}

  // --- Helper Methods (Equivalent to your Private C# Helpers) ---

  static String getDongleError(int code) {
    switch (code) {
      case 0x10: return "DONGLEERROR_COMMANDNOTSUPPORTED";
      case 0x12: return "DONGLEERROR_INPUTNOTSUPPORTED";
      case 0x13: return "DONGLEERROR_INVALIDFORMAT";
      case 0x15: return "DONGLEERROR_CRCFAILURE";
      case 0x16: return "DONGLEERROR_PROTOCOLNOTSET";
      case 0x33: return "DONGLEERROR_SECURITYACCESSDENIED";
      default: return "DONGLE_UNKNOWN_ERROR";
    }
  }

 
/// New method: RP1210 Protocol Response Decoding
  static (Uint8List?, String) checkResponseRP1210(Uint8List pidBytesResponse, Uint8List requestBytes) {
    Uint8List? dataArray = pidBytesResponse;
    String status = "NOERROR";
    
    try {
      var responeBytes = pidBytesResponse;
      // ignore: unused_local_variable
      var request = requestBytes;
      int nextpacketindex = 0;
      bool endofpacket = false;

      while (!endofpacket) {
        // 1. Check for Negative Response or Pending Frame (0x7F)
        if (responeBytes[nextpacketindex] == 0x7F) {
          if (responeBytes[nextpacketindex + 2] == 0x78) {
            // Response Pending: Skip this frame and prepare to read more
            nextpacketindex += 7;
            endofpacket = false;
            
            if (nextpacketindex > responeBytes.length - 1) {
              status = "READAGAIN";
              endofpacket = true;
              break;
            }
          } else {
            // Actual ECU Error
            endofpacket = true;
            int errorCode = responeBytes[nextpacketindex + 2];
            status = getEcuErrorStatusRP1210(errorCode);
            
            // Extract the 3-byte error frame
            dataArray = responeBytes.sublist(nextpacketindex, nextpacketindex + 3);
          }
        } 
        else {
          // 2. Protocol Validation (Response = Request + 0x40)
          int respFirstByte = responeBytes[0];
          int reqFirstByte = requestBytes[0];

          if (respFirstByte == (reqFirstByte + 0x40)) {
            status = "NOERROR";
            endofpacket = true;
          } 
          else {
            // 3. Handle specific No Response or Fragmented data
            if (respFirstByte == 0x01) {
              status = "ECUERROR_NORESEEPONSEFROMECU";
            } else {
              // Usually implies we haven't received the full header yet
              status = "READAGAIN";
            }
            endofpacket = true;
          }
        }
      }
      return (dataArray, status);
    } catch (ex, stack) {
      return (null, "EXCEPTION: $ex\n$stack");
    }
  }

//   static (Uint8List?, String) checkResponseRP1210(Uint8List pidBytesResponse, Uint8List requestBytes) {
//     try {
//       if (pidBytesResponse.isEmpty) return (null, "READAGAIN");

//       // Convert to string to check for dongle-level errors quickly
//       String rawText = String.fromCharCodes(pidBytesResponse);
//       if (rawText.contains("No Resp From Dongle")) return (null, "No Resp From Dongle");

//       int expectedSid = requestBytes[0] + 0x40; // e.g., 0x50
      
//       // --- THE SCANNER LOOP ---
//       // Instead of looking at [0], we scan the entire buffer for the SID or 0x7F
//       for (int i = 0; i < pidBytesResponse.length; i++) {
        
//         // 1. Found Positive Response (e.g., 50 03)
//         if (pidBytesResponse[i] == expectedSid) {
//           return (pidBytesResponse.sublist(i), "NOERROR");
//         }

//         // 2. Found Negative Response or Pending (7F)
//         if (pidBytesResponse[i] == 0x7F && (i + 2) < pidBytesResponse.length) {
//           int nrc = pidBytesResponse[i + 2];
          
//           if (nrc == 0x78) {
//             // It's a "Response Pending" - we need to keep reading
//             return (null, "READAGAIN");
//           } else {
//             // It's a real ECU Error (e.g., 7F 10 22)
//             String errorStatus = getEcuErrorStatusRP1210(nrc);
//             return (pidBytesResponse.sublist(i, i + 3), errorStatus);
//           }
//         }
//       }

//       // 3. If we scanned everything and found no SID and no 7F
//       return (null, "READAGAIN");

//     } catch (ex, stack) {
//       return (null, "EXCEPTION: $ex\n$stack");
//     }
// }

static ResponseArrayStatus checkResponseRP12101(
  Uint8List pidBytesResponse,
  Uint8List requestBytes,
) {
  Uint8List? dataArray = pidBytesResponse;
  String status = "NOERROR";

  try {
    Uint8List responeBytes = pidBytesResponse;
    Uint8List request = requestBytes;

    int nextpacketindex = 0;
    bool endofpacket = false;

    while (!endofpacket) {
      if (responeBytes[nextpacketindex] == 0x7F) {
        if (responeBytes.length > nextpacketindex + 2 &&
            responeBytes[nextpacketindex + 2] == 0x78) {
          nextpacketindex += 7;

          if (nextpacketindex > responeBytes.length - 1) {
            status = "READAGAIN";
            endofpacket = true;
            break;
          }
        } else {
          endofpacket = true;

          int errorCode =
              responeBytes.length > nextpacketindex + 2
                  ? responeBytes[nextpacketindex + 2]
                  : 0x00;

          switch (errorCode) {
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

          if (responeBytes.length >= nextpacketindex + 3) {
            dataArray = responeBytes.sublist(
                nextpacketindex, nextpacketindex + 3);
          }
        }
      } else {
        int respFirstByte = responeBytes[0];
        int reqFirstByte = request[0];

        if (respFirstByte == reqFirstByte + 0x40) {
          status = "NOERROR";
        } else {
          status = respFirstByte == 0x01
              ? "ECUERROR_NORESPONSEFROMECU"
              : "READAGAIN";
        }

        endofpacket = true;
      }
    }
  } catch (e) {
    dataArray = null;
    status = e.toString();
  }

  return ResponseArrayStatus(
    ecuResponse: pidBytesResponse,
    ecuResponseStatus: status,
    actualDataBytes: dataArray,
  );
}

 

//   /// Extensive Error Mapping for RP1210/UDS
  static String getEcuErrorStatusRP1210(int code) {
    switch (code) {
      case 0x10: return "ECUERROR_GENERALREJECT";
      case 0x11: return "ECUERROR_SERVICENOTSUPPORTED";
      case 0x12: return "ECUERROR_SUBFUNCTIONNOTSUPPORTED";
      case 0x13: return "ECUERROR_INVALIDFORMAT";
      case 0x14: return "ECUERROR_RESPONSETOOLONG";
      case 0x21: return "ECUERROR_BUSYREPEATREQUEST";
      case 0x22: return "ECUERROR_CONDITIONSNOTCORRECT";
      case 0x24: return "ECUERROR_REQUESTSEQUENCEERROR";
      case 0x31: return "ECUERROR_REQUESTOUTOFRANGE";
      case 0x33: return "ECUERROR_SECURITYACCESSDENIED";
      case 0x35: return "ECUERROR_INVALIDKEY";
      case 0x36: return "ECUERROR_EXCEEDEDNUMBEROFATTEMPTS";
      case 0x37: return "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED";
      case 0x70: return "ECUERROR_UPLOADDOWNLOADNOTACCEPTED";
      case 0x71: return "ECUERROR_TRANSFERDATASUSPENDED";
      case 0x72: return "ECUERROR_GENERALPROGRAMMINGFAILURE";
      case 0x73: return "ECUERROR_WRONGBLOCKSEQCOUNTER";
      case 0x7E: return "ECUERROR_SUBFNNOTSUPPORTEDINACTIVESESSION";
      case 0x7F: return "ECUERROR_SERVICENOTSUPPORTEDINACTIVESESSION";
      case 0x81: return "ECUERROR_RPMTOOHIGH";
      case 0x82: return "ECUERROR_RPMTOOLOW";
      case 0x92: return "ECUERROR_VOLTAGETOOHIGH";
      case 0x93: return "ECUERROR_VOLTAGETOOLOW";
      default: return "ECU_UNKNOWN_ERROR (0x${code.toRadixString(16)})";
    }
  }
 
static (Uint8List?, String) checkResponseIVNwithChannel(
      Uint8List pidBytesResponse, Uint8List requestBytes, String reqtype1) {
    Uint8List? dataArray;
    String status = "NOERROR";
    
    try {
      var responeBytes = pidBytesResponse;
      String expectedframe = "";
      String reqtype = "";
      int nextpacketindex = 0;
      bool endofpacket = false;
      int framelen = 0;

      // 1. Determine Request Type and Expected Frame
      if (requestBytes[0] == 0x20) {
        // reqtype = "CONFIGREQUEST";
        switch (requestBytes[3]) {
          case 0x01: case 0x02: case 0x04: case 0x06: case 0x08:
          case 0x0A: case 0x0C: case 0x0E: case 0x10: case 0x11:
          case 0x12: case 0x13: case 0x15: case 0x17:
            expectedframe = "DONGLECONFIGACK";
            break;
          case 0x03: case 0x05: case 0x07: case 0x09: case 0x0B:
          case 0x0D: case 0x0F: case 0x14:
            expectedframe = "DONGLECONFIGRESPONSE";
            break;
        }
      } else if (requestBytes[0] == 0x40) {
        reqtype = "DATAREQUEST";
        expectedframe = "DONGLECONFIGACK";
      }

      // 2. Start Parser
      while (!endofpacket) {
        // Ensure index is within bounds
        if (nextpacketindex >= responeBytes.length) {
          status = "READAGAIN";
          break;
        }

        if (responeBytes[nextpacketindex] == 0x20) {
          framelen = responeBytes[nextpacketindex + 1];
          
          if (reqtype == "CONFIGREQUEST") {
            endofpacket = true;
            if (expectedframe == "DONGLECONFIGRESPONSE") {
              // Extract frame using sublist (equiv to Array.Copy)
              dataArray = responeBytes.sublist(
                  nextpacketindex + 4, nextpacketindex + 4 + framelen);
            }
          } 
          // Check for Positive Acknowledgement (0x01)
          else if (responeBytes[nextpacketindex + 1] == 0x01) {
            if (firstposdongleackreceived) {
              firstposdongleackreceived = false;
              endofpacket = true;
              status = "NOERROR";
              print("Jugaad - Second positive ack received");
              break;
            }

            nextpacketindex += 6;
            firstposdongleackreceived = true;

            if (nextpacketindex < responeBytes.length) {
              endofpacket = false;
            } else {
              status = "READAGAIN";
              endofpacket = true;
              break;
            }
          } 
          // Negative acknowledgement from dongle
          else {
            endofpacket = true;
            firstposdongleackreceived = false;
            int errorCode = responeBytes[nextpacketindex + 4];
            status = getDongleError(errorCode);
          }
        } 
        // IF there is no response from the ECU for P2MAX time
        else if (((responeBytes[nextpacketindex] & 0xF0) == 0x40) && (responeBytes[nextpacketindex + 1] == 0x00)) {
          status = "ECUERROR_NORESPONSEFROMECU";
          endofpacket = true;
          firstposdongleackreceived = false;
          break;
        } 
        // Data frame response (starts with 0x4X)
        else if ((responeBytes[nextpacketindex] & 0xF0) == 0x40) {
          firstposdongleackreceived = false;
          int msglen = ((responeBytes[nextpacketindex] & 0x0F) << 8) + responeBytes[nextpacketindex + 1];
          framelen = msglen;

          if (responeBytes[nextpacketindex + 3] == 0x7F) {
            if (responeBytes[nextpacketindex + 5] == 0x78) {
              nextpacketindex += 8;
              endofpacket = false;
              if (nextpacketindex > responeBytes.length - 1) {
                status = "READAGAIN";
                endofpacket = true;
                break;
              }
            } else {
              endofpacket = true;
              int ecuError = responeBytes[nextpacketindex + 5];
              status = _mapEcuError(ecuError);
            }
          } 
          // Successful data response
          else {
            endofpacket = true;
            val = "${_byteArrayToString(responeBytes)}, $nextpacketindex, (length: $framelen)";
            dataArray = responeBytes.sublist(
                nextpacketindex + 3, nextpacketindex + 3 + framelen);
          }
        } 
        else {
          status = "GENERALERROR_INVALIDRESPFROMDONGLE";
          firstposdongleackreceived = false;
          endofpacket = true;
        }
      }
      return (dataArray, status);
    } catch (ex, stack) {
      return (null, "$val\n\n$ex\n\n$stack");
    }
  }

  
  static String _byteArrayToString(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(" ").toUpperCase();
}
