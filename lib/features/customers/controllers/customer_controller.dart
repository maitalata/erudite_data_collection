import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

final customerFormControllerProvider = Provider<CustomerFormController>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final profile = authState.value?.profile;
  if (profile == null) {
    throw StateError('No authenticated profile available');
  }
  return CustomerFormController(repository: repo, profile: profile);
});

class CustomerFormController {
  CustomerFormController({required this.repository, required this.profile});

  final CustomerRepository repository;
  final Profile profile;
  final _uuid = const Uuid();

  Future<void> saveCustomer({
    String? localId,
    String? remoteId,
    required String name,
    required String address,
    required String phone,
    String? email,
    required String meterNo,
    required String accountNo,
    required String poleNo,
    required PlanType plan,
    PlanBUnit? planUnit,
    String? planCode,
    double? latitude,
    double? longitude,
  }) async {
    if (plan == PlanType.planB && planUnit == null) {
      throw const CustomerValidationException(
        'Plan B requires a unit selection',
      );
    }

    final now = DateTime.now().toUtc();
    final customer = Customer(
      localId: localId != null ? int.tryParse(localId) : null,
      remoteId: remoteId ?? _uuid.v4(),
      collectorId: profile.id,
      customerName: name,
      address: address,
      phone: phone,
      email: email?.isEmpty == true ? null : email,
      meterNo: meterNo,
      accountNo: accountNo,
      poleNo: poleNo,
      plan: plan,
      planUnit: planUnit,
      planCode: planCode,
      latitude: latitude,
      longitude: longitude,
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveCustomer(customer, profile);
  }

  Future<Coordinate?> captureCoordinate() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied) {
        throw const CustomerValidationException('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const CustomerValidationException(
        'Location permissions are permanently denied. Update settings to enable.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return Coordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

class Coordinate {
  const Coordinate({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

class CustomerValidationException implements Exception {
  const CustomerValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}
