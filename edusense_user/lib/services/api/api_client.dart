import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    required this.statusCode,
  });

  factory ApiResponse.success(T data, int statusCode) {
    return ApiResponse(success: true, data: data, statusCode: statusCode);
  }

  factory ApiResponse.error(String error, int statusCode) {
    return ApiResponse(success: false, error: error, statusCode: statusCode);
  }
}

class ApiClient {
  // GET request with error handling
  static Future<ApiResponse<T>> get<T>(
    String url, {
    Map<String, String>? headers,
    required T Function(dynamic data) fromJson,
  }) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return ApiResponse.success(fromJson(data), response.statusCode);
      } else {
        return ApiResponse.error(
          'Server error: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Connection error: $e', 0);
    }
  }
}
