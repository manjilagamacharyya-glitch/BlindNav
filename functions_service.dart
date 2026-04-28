class FunctionsService {
  static Future<Map<String, dynamic>> verifySafePath(String pathId) async {
    // Mock response since Cloud Functions not deployed
    await Future.delayed(const Duration(seconds: 1));
    return {
      'verified': true,
      'riskScore': 0.12,
      'message': 'Route verified locally for demo.',
    };
  }

  static Future<Map<String, dynamic>> notifyEmergency(String message) async {
    // Mock response
    await Future.delayed(const Duration(seconds: 1));
    return {
      'success': true,
      'eventId': 'mock-event-${DateTime.now().millisecondsSinceEpoch}',
    };
  }
}
