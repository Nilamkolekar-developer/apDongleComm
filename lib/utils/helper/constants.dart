class DWCommandId {
  static const int clientConnect = 0x01;
  static const int clientDisconnect = 0x02;
  static const int readVersion = 0x03;
  static const int sendCommand = 0x04;
  static const int sendMessage = 0x05;
  static const int readMessage = 0x06;
  static const int doipSendMessage = 0x07;
  static const int doipReadMessage = 0x08;
}

class DoipMsgType {
  static const int routineActivationReq = 0x0001;
  static const int routineActivationResp = 0x0002;
  static const int diagnosticMsg = 0x8001;
  static const int diagnosticMsgAck = 0x8002;
  static const int diagnosticMsgNack = 0x8003;
}