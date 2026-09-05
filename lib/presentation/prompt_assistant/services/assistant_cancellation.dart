import 'package:dio/dio.dart';

extension AssistantCancellation on CancelToken {
  void throwIfCancelled() {
    if (cancelError case final error?) throw error;
  }
}
