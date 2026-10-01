import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'logger_service.dart';

class ApiService {
  String? _token;
  final LoggerService _log;

  void Function()? onUnauthorized;

  ApiService({LoggerService? logger}) : _log = logger ?? LoggerService();

  void setToken(String? token) {
    _log.info('Token seteado: ${token != null ? "SÍ (${token.substring(0, 20)}...)" : "NO"}',
        source: 'ApiService');
    _token = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Auth ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'getMe') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final url = '${ApiConfig.baseUrl}/auth/google-login';
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    return _handleResponse(res, source: 'googleLogin');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'updateProfile') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = '${ApiConfig.baseUrl}/auth/login';
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(res, source: 'login');
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, {String? shortName}) async {
    final url = '${ApiConfig.baseUrl}/auth/register';
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'short_name': shortName}),
    );
    return _handleResponse(res, source: 'register');
  }

  // ── Categories ──────────────────────────────────────────────────

  Future<List<dynamic>> getCategories({String? type, int? householdId}) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (householdId != null) params['household_id'] = householdId.toString();
    final uri = Uri.parse('${ApiConfig.baseUrl}/categories').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(res, source: 'getCategories') as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/categories'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'createCategory') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCategory(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/categories/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'updateCategory') as Map<String, dynamic>;
  }

  Future<void> deleteCategory(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/categories/$id'),
      headers: _headers,
    );
    _handleResponse(res, source: 'deleteCategory');
  }

  // ── Transactions ────────────────────────────────────────────────

  Future<List<dynamic>> getTransactions({int? month, int? year, int? userId, String? type, int? householdId}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = month.toString();
    if (year != null) params['year'] = year.toString();
    if (userId != null) params['user_id'] = userId.toString();
    if (type != null) params['type'] = type.toString();
    if (householdId != null) params['household_id'] = householdId.toString();
    final uri = Uri.parse('${ApiConfig.baseUrl}/transactions').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(res, source: 'getTransactions') as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/transactions'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'createTransaction') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTransaction(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/transactions/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'updateTransaction') as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/transactions/$id'),
      headers: _headers,
    );
    _handleResponse(res, source: 'deleteTransaction');
  }

  // ── Monthly Summary ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getMonthlySummary(int month, int year, {int? householdId}) async {
    final params = <String, String>{
      'month': month.toString(),
      'year': year.toString(),
    };
    if (householdId != null) params['household_id'] = householdId.toString();
    final uri = Uri.parse('${ApiConfig.baseUrl}/monthly/summary').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(res, source: 'getMonthlySummary') as Map<String, dynamic>;
  }

  // ── Savings Accounts ────────────────────────────────────────────

  Future<List<dynamic>> getSavingAccounts({int? householdId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/savings/accounts').replace(
      queryParameters: householdId != null ? {'household_id': householdId.toString()} : null,
    );
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(res, source: 'getSavingAccounts') as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSavingAccount(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/savings/accounts'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'createSavingAccount') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSavingAccount(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/savings/accounts/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'updateSavingAccount') as Map<String, dynamic>;
  }

  Future<void> deleteSavingAccount(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/savings/accounts/$id'),
      headers: _headers,
    );
    _handleResponse(res, source: 'deleteSavingAccount');
  }

  // ── Savings Balances ────────────────────────────────────────────

  Future<List<dynamic>> getSavings({int? accountId, int? month, int? year}) async {
    final params = <String, String>{};
    if (accountId != null) params['account_id'] = accountId.toString();
    if (month != null) params['month'] = month.toString();
    if (year != null) params['year'] = year.toString();
    final uri = Uri.parse('${ApiConfig.baseUrl}/savings').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(res, source: 'getSavings') as List<dynamic>;
  }

  Future<Map<String, dynamic>> getSavingsSummary({int? householdId, int? year}) async {
    final params = <String, String>{};
    if (householdId != null) params['household_id'] = householdId.toString();
    if (year != null) params['year'] = year.toString();
    final uri = Uri.parse('${ApiConfig.baseUrl}/savings/summary').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(res, source: 'getSavingsSummary') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSaving(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/savings'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'createSaving') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSaving(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/savings/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'updateSaving') as Map<String, dynamic>;
  }

  Future<void> deleteSaving(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/savings/$id'),
      headers: _headers,
    );
    _handleResponse(res, source: 'deleteSaving');
  }

  Future<Map<String, dynamic>> setMonthlyFlow({
    required int year,
    required int month,
    required double amountArs,
    String? note,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/savings/monthly-flow'),
      headers: _headers,
      body: jsonEncode({
        'year': year,
        'month': month,
        'amount_ars': amountArs,
        if (note != null) 'note': note,
      }),
    );
    return _handleResponse(res, source: 'setMonthlyFlow') as Map<String, dynamic>;
  }

  Future<void> deleteMonthlyFlow({required int year, required int month}) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/savings/monthly-flow?year=$year&month=$month'),
      headers: _headers,
    );
    _handleResponse(res, source: 'deleteMonthlyFlow');
  }

  // ── Households ──────────────────────────────────────────────────

  Future<List<dynamic>> getMyHouseholds() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/households/mine'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'getMyHouseholds') as List<dynamic>;
  }

  Future<Map<String, dynamic>> createHousehold(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/households'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'createHousehold') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHousehold(int id) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/households/$id'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'getHousehold') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateHousehold(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/households/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res, source: 'updateHousehold') as Map<String, dynamic>;
  }

  Future<void> deleteHousehold(int householdId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/households/$householdId'),
      headers: _headers,
    );
    _handleResponse(res, source: 'deleteHousehold');
  }


  // ── Household Members ───────────────────────────────────────────

  Future<List<dynamic>> getMembers(int householdId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/households/$householdId/members'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'getMembers') as List<dynamic>;
  }

  Future<void> removeMember(int householdId, int memberId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/households/$householdId/members/$memberId'),
      headers: _headers,
    );
    _handleResponse(res, source: 'removeMember');
  }

  Future<Map<String, dynamic>> updateMemberRole(int householdId, int memberId, String role) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/households/$householdId/members/$memberId/role'),
      headers: _headers,
      body: jsonEncode({'role': role}),
    );
    return _handleResponse(res, source: 'updateMemberRole') as Map<String, dynamic>;
  }

  // ── Invitations ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> inviteMember(int householdId, String email, {String role = 'read'}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/households/$householdId/invite'),
      headers: _headers,
      body: jsonEncode({'email': email, 'role': role}),
    );
    return _handleResponse(res, source: 'inviteMember') as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPendingInvitations() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/households/invitations/pending'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'getPendingInvitations') as List<dynamic>;
  }

  Future<Map<String, dynamic>> acceptInvitation(String token) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/households/invitations/$token/accept'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'acceptInvitation') as Map<String, dynamic>;
  }

  Future<void> declineInvitation(int invitationId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/households/invitations/$invitationId'),
      headers: _headers,
    );
    _handleResponse(res, source: 'declineInvitation');
  }

  // ── Platform Admin (App Owner) ──────────────────────────────────

  Future<Map<String, dynamic>> getAdminUsers() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/admin/users'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'getAdminUsers') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> authorizeEmail(String email, {String? notes}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/admin/authorized-emails'),
      headers: _headers,
      body: jsonEncode({'email': email, 'notes': notes}),
    );
    return _handleResponse(res, source: 'authorizeEmail') as Map<String, dynamic>;
  }

  Future<void> revokeAuthorizedEmail(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/admin/authorized-emails/$id'),
      headers: _headers,
    );
    _handleResponse(res, source: 'revokeAuthorizedEmail');
  }

  Future<Map<String, dynamic>> toggleUserStatus(int userId) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/toggle-status'),
      headers: _headers,
    );
    return _handleResponse(res, source: 'toggleUserStatus') as Map<String, dynamic>;
  }

  // ── App Version / Updates ───────────────────────────────────────

  Future<Map<String, dynamic>?> checkAppVersion(String currentVersion) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/version/latest?current_version=$currentVersion'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _log.warning('Error al consultar versión de app: $e', source: 'ApiService');
      return null;
    }
  }

  // ── Response handler ───────────────────────────────────────────


  dynamic _handleResponse(http.Response res, {String source = 'api'}) {
    _log.debug('$source → HTTP ${res.statusCode}', source: 'ApiService');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body);
      } catch (e) {
        return res.body;
      }
    }

    String errorMsg = 'Error desconocido (HTTP ${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) {
        errorMsg = body['error'].toString();
      } else if (body is Map && body['message'] != null) {
        errorMsg = body['message'].toString();
      } else {
        errorMsg = res.body;
      }
    } catch (_) {
      // Si el backend responde texto plano o HTML (ej. 429 Too Many Requests, 500 Server Error)
      final cleanText = res.body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleanText.isNotEmpty) {
        errorMsg = cleanText;
      }
    }

    _log.error('$source → HTTP ${res.statusCode}: $errorMsg',
        source: 'ApiService',
        details: {
          'statusCode': res.statusCode,
          'error': errorMsg,
          'rawBody': res.body.substring(0, min(res.body.length, 300)),
        });

    if (res.statusCode == 401) {
      onUnauthorized?.call();
    }

    throw ApiException(statusCode: res.statusCode, message: errorMsg);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}

