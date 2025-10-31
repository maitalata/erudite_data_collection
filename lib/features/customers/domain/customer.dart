import 'package:collection/collection.dart';

enum PlanType { planA, planB }

enum PlanBUnit { unitOne, unitTwo }

extension PlanTypeX on PlanType {
  String get label => this == PlanType.planA ? 'Plan A' : 'Plan B';

  String get storageValue => this == PlanType.planA ? 'A' : 'B';

  static PlanType fromStorage(String value) {
    return value.toUpperCase() == 'A' ? PlanType.planA : PlanType.planB;
  }
}

extension PlanBUnitX on PlanBUnit {
  String get label => switch (this) {
    PlanBUnit.unitOne => 'Unit One',
    PlanBUnit.unitTwo => 'Unit Two',
  };

  String get storageValue => switch (this) {
    PlanBUnit.unitOne => 'unit_one',
    PlanBUnit.unitTwo => 'unit_two',
  };

  static PlanBUnit? fromStorage(String? value) {
    if (value == null) return null;
    return PlanBUnit.values.firstWhereOrNull(
      (unit) => unit.storageValue == value,
    );
  }
}

class Customer {
  const Customer({
    this.localId,
    required this.remoteId,
    required this.collectorId,
    required this.customerName,
    required this.address,
    required this.phone,
    this.email,
    required this.meterNo,
    required this.accountNo,
    required this.poleNo,
    required this.plan,
    this.planUnit,
    this.planCode,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
    this.isDirty = true,
    this.isDeleted = false,
  });

  final int? localId;
  final String remoteId;
  final String collectorId;
  final String customerName;
  final String address;
  final String phone;
  final String? email;
  final String meterNo;
  final String accountNo;
  final String poleNo;
  final PlanType plan;
  final PlanBUnit? planUnit;
  final String? planCode;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final bool isDirty;
  final bool isDeleted;

  bool get requiresPlanUnit => plan == PlanType.planB;

  Customer copyWith({
    int? localId,
    String? remoteId,
    String? collectorId,
    String? customerName,
    String? address,
    String? phone,
    String? email,
    String? meterNo,
    String? accountNo,
    String? poleNo,
    PlanType? plan,
    PlanBUnit? planUnit,
    bool setPlanUnitToNull = false,
    String? planCode,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isDirty,
    bool? isDeleted,
  }) {
    return Customer(
      localId: localId ?? this.localId,
      remoteId: remoteId ?? this.remoteId,
      collectorId: collectorId ?? this.collectorId,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      meterNo: meterNo ?? this.meterNo,
      accountNo: accountNo ?? this.accountNo,
      poleNo: poleNo ?? this.poleNo,
      plan: plan ?? this.plan,
      planUnit: setPlanUnitToNull ? null : planUnit ?? this.planUnit,
      planCode: planCode ?? this.planCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'local_id': localId,
      'remote_id': remoteId,
      'collector_id': collectorId,
      'customer_name': customerName,
      'address': address,
      'phone': phone,
      'email': email,
      'meter_no': meterNo,
      'account_no': accountNo,
      'pole_no': poleNo,
      'plan': plan.storageValue,
      'plan_unit': planUnit?.storageValue,
      'plan_code': planCode,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'is_dirty': isDirty ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toRemotePayload() {
    return {
      'id': remoteId,
      'collector_id': collectorId,
      'customer_name': customerName,
      'address': address,
      'phone': phone,
      'email': email,
      'meter_no': meterNo,
      'account_no': accountNo,
      'pole_no': poleNo,
      'plan': plan.storageValue,
      'plan_unit': planUnit?.storageValue,
      'plan_code': planCode,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced_at': syncedAt?.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  static Customer fromLocalMap(Map<String, dynamic> map) {
    return Customer(
      localId: map['local_id'] as int?,
      remoteId: (map['remote_id'] as String?) ?? '',
      collectorId: map['collector_id'] as String,
      customerName: map['customer_name'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      meterNo: map['meter_no'] as String,
      accountNo: map['account_no'] as String,
      poleNo: map['pole_no'] as String,
      plan: PlanTypeX.fromStorage(map['plan'] as String),
      planUnit: PlanBUnitX.fromStorage(map['plan_unit'] as String?),
      planCode: map['plan_code'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncedAt: (map['synced_at'] as String?) != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      isDirty: (map['is_dirty'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  static Customer fromRemoteMap(Map<String, dynamic> map) {
    return Customer(
      remoteId: map['id'] as String,
      collectorId: map['collector_id'] as String,
      customerName: map['customer_name'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      meterNo: map['meter_no'] as String,
      accountNo: map['account_no'] as String,
      poleNo: map['pole_no'] as String,
      plan: PlanTypeX.fromStorage(map['plan'] as String),
      planUnit: PlanBUnitX.fromStorage(map['plan_unit'] as String?),
      planCode: map['plan_code'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
      syncedAt: (map['synced_at'] as String?) != null
          ? DateTime.parse(map['synced_at'] as String).toUtc()
          : null,
      isDirty: false,
      isDeleted: (map['is_deleted'] as bool?) ?? false,
    );
  }
}
