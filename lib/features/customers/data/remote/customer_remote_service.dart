import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/customer.dart';

class CustomerRemoteService {
  CustomerRemoteService(this._client);

  final SupabaseClient _client;

  Future<List<Customer>> fetchCustomerUpdates({
    DateTime? since,
    bool includeDeleted = false,
  }) async {
    var query = _client.from('customers').select('*');

    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }

    if (!includeDeleted) {
      query = query.eq('is_deleted', false);
    }

    final response = await query.order('updated_at', ascending: false);
    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((row) => Customer.fromRemoteMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertCustomers(List<Customer> customers) async {
    if (customers.isEmpty) return;
    final payload = customers
        .map((customer) => customer.toRemotePayload())
        .toList();
    await _client.from('customers').upsert(payload);
  }

  Future<void> deleteCustomers(List<String> remoteIds) async {
    if (remoteIds.isEmpty) return;
    for (final id in remoteIds) {
      await _client.from('customers').update({'is_deleted': true}).eq('id', id);
    }
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();
    return data;
  }

  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    final data = await _client.from('profiles').select('*').order('created_at');
    return (data as List<dynamic>)
        .map((row) => row as Map<String, dynamic>)
        .toList();
  }

  Future<void> updateUserRoleStatus({
    required String accessToken,
    required String targetUserId,
    required String role,
    required String status,
  }) async {
    final response = await _client.functions.invoke(
      'manage-user',
      body: {'target_user_id': targetUserId, 'role': role, 'status': status},
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.status >= 400) {
      throw Exception(
        'User update failed (${response.status}): ${response.data}',
      );
    }
  }

  Future<Map<String, dynamic>> createUser({
    required String accessToken,
    required String email,
    String? fullName,
    required String role,
    required String status,
    bool sendInvite = true,
    String? password,
  }) async {
    final payload =
        <String, dynamic>{
          'action': 'create',
          'email': email,
          'full_name': fullName,
          'role': role,
          'status': status,
          'send_invite': sendInvite,
          'password': password,
        }..removeWhere(
          (key, value) => value == null || (value is String && value.isEmpty),
        );

    final response = await _client.functions.invoke(
      'manage-user',
      body: payload,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.status >= 400) {
      throw Exception(
        'User creation failed (${response.status}): ${response.data}',
      );
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<void> updateUserPassword({
    required String accessToken,
    required String userId,
    required String password,
    bool sendInvite = false,
  }) async {
    final payload =
        <String, dynamic>{
          'action': 'set_password',
          'target_user_id': userId,
          'password': password,
          'send_invite': sendInvite,
        }..removeWhere(
          (key, value) => value == null || (value is String && value.isEmpty),
        );

    final response = await _client.functions.invoke(
      'manage-user',
      body: payload,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.status >= 400) {
      throw Exception(
        'Password update failed (${response.status}): ${response.data}',
      );
    }
  }
}
