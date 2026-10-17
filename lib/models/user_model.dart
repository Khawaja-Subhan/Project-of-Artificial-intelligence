enum UserRole {
  reader,
  supervisor,
  admin,
}

/// Represents an authenticated user in the DISCO Mobile Meter Reading ecosystem (FR-1, FR-4).
class UserModel {
  final String id;
  final String name;
  final String mobile;
  final UserRole role;
  final String discoCode;
  final List<String> assignedRouteIds;
  final bool active;

  const UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.discoCode,
    required this.assignedRouteIds,
    this.active = true,
  });

  String get roleDisplayName {
    switch (role) {
      case UserRole.reader:
        return 'Meter Reader (Field Staff)';
      case UserRole.supervisor:
        return 'Sub-Divisional Supervisor';
      case UserRole.admin:
        return 'MMR Administrator / AI Ops';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'role': role.name,
    'discoCode': discoCode,
    'assignedRouteIds': assignedRouteIds,
    'active': active,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      mobile: json['mobile'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.reader,
      ),
      discoCode: json['discoCode'] as String? ?? 'LESCO',
      assignedRouteIds: List<String>.from(json['assignedRouteIds'] ?? []),
      active: json['active'] as bool? ?? true,
    );
  }
}
