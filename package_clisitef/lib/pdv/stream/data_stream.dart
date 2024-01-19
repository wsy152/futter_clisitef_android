library clisitef;

import 'dart:async';

import 'package:flutter_clisitef/model/clisitef_data.dart';

class DataStream {
  final _controller = StreamController<CliSiTefData>.broadcast();

  Stream<CliSiTefData> get stream => _controller.stream;

  StreamSink<CliSiTefData> get sink => _controller.sink;
}
