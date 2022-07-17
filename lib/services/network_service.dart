import 'dart:developer';

import 'package:dio/dio.dart';

class NetworkService {
  static initialize(
    Map<String, dynamic> header,
  ) {
    _dio = Dio();

    _dio?.options = BaseOptions(
      headers: header,
    );
  }

  static Dio? _dio;

  static Future<Response<dynamic>?> download(
    String url,
    String savePath, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    assert(_dio != null);

    final Response<dynamic>? res = await _dio?.download(
      url,
      savePath,
      data: data,
      queryParameters: queryParameters,
      onReceiveProgress: (from, total) {
        printer(total / from);
      },
    );

    return res;
  }
}

const int _downloadBar = 20;

void printer(double percentage) {
  final double progress = (double.tryParse(percentage.toStringAsFixed(1)) ?? 0);
  final StringBuffer sb = StringBuffer();

  int progressBar = 0;
  sb.write('|');
  if (progress > 0) {
    progressBar += (progress * _downloadBar).floor();
  }

  for (int i = 0; i < progressBar; i++) {
    sb.write('-');
  }
  sb.write('>');

  for (int i = 0; i < _downloadBar - progressBar; i++) {
    sb.write(' ');
  }
  sb.write('|');

  log(sb.toString());
}
