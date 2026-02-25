import 'dart:typed_data';

class ResponseArrayStatus {
  String? ecuResponseStatus;
  Uint8List? ecuResponse;
  Uint8List? actualDataBytes;
Uint8List? sentBytes;

  ResponseArrayStatus({
    this.ecuResponseStatus,
    this.ecuResponse,
    this.actualDataBytes,
    this.sentBytes,
  });
}

class IvnResponseArrayStatus {
  String? frame;
  String? ecuResponseStatus;
  Uint8List? ecuResponse;
  Uint8List? actualDataBytes;

  IvnResponseArrayStatus({
    this.frame,
    this.ecuResponseStatus,
    this.ecuResponse,
    this.actualDataBytes,
  });
}

// Note the lowercase 'i' here to match your C# namespace call
class ResponseArrayStatusivn {
  String? ecuResponseStatus;
  Uint8List? actualFrameBytes;

  ResponseArrayStatusivn({
    this.ecuResponseStatus,
    this.actualFrameBytes,
  });
}