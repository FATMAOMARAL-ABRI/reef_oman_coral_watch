import 'package:dio/dio.dart';

class UniversityApiClient {
  final Dio _dio;

  UniversityApiClient({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: 'https://squ-reef-api.example.com'));

  /// Aggregated data = map like:
  /// { "regionA": {"Healthy": 10, "Bleached": 3, "Dead": 1}, ... }
  Future<void> syncAggregatedData(Map<String, Map<String, int>> data) async {
    try {
      await _dio.post('/syncCoralReports', data: data);
    } catch (e) {
      // For this assignment, just log / ignore errors.
      // In production you'd surface this error to the user.
    }
  }
}
