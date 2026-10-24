import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'outbox.dart';
import 'prefs.dart';

/// Error shown to the user as-is (the server sends human readable messages).
class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.code, this.isNetwork = false});
  final String message;
  final int status;
  final String? code;

  /// True when the request never reached the server (no internet / timeout). Safe to retry later.
  final bool isNetwork;

  /// 428 from the server: signed in, but no business created yet (onboarding not finished).
  bool get businessSetupRequired => status == 428;

  @override
  String toString() => message;
}

/// Thin HTTP client for the Galla Pro backend. Every call carries the Firebase ID token.
///
/// Set the server address at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
/// (10.0.2.2 reaches your computer from the Android emulator.)
class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000');
  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _http = http.Client();

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiException('Please sign in again.', status: 401);
    final token = await user.getIdToken();
    return {
      if (AppPrefs.I.businessId != null) 'X-Business-Id': AppPrefs.I.businessId!,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) q[k] = '$v';
    });
    return Uri.parse('$baseUrl/api$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, Duration? timeout}) =>
      _send('GET', path, query: query, timeout: timeout);
  Future<Map<String, dynamic>> post(String path, [Object? body, Duration? timeout]) =>
      _send('POST', path, body: body ?? {}, timeout: timeout);
  /// POST that survives being offline: on a network failure the request is stored on the phone (with a client_ref so the
  /// server can ignore a duplicate) and the result has `queued: true`. Used for invoices, payments and expenses.
  Future<Map<String, dynamic>> postQueued(String path, Map<String, dynamic> body) async {
    final withRef = {...body, 'client_ref': body['client_ref'] ?? Outbox.newRef()};
    try {
      return await post(path, withRef);
    } on ApiException catch (e) {
      if (e.isNetwork && Outbox.queueable.contains(path)) {
        await Outbox.I.enqueue(path, withRef);
        return {'queued': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(String path, Object body) => _send('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body, Duration? timeout}) async {
    final headers = await _headers();
    final uri = _uri(path, query);
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout ?? _timeout));
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Check your internet and try again.', isNetwork: true);
    } catch (_) {
      throw ApiException('Cannot reach the server. Check your internet connection.', isNetwork: true);
    }

    Map<String, dynamic> data = {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // non-JSON body; handled by status below
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final msg = (data['error'] as String?) ?? 'Something went wrong (${res.statusCode}).';
    throw ApiException(msg, status: res.statusCode, code: data['code'] as String?);
  }
}
