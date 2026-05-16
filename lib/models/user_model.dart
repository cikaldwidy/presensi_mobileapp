class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.noHp,
    this.alamat,
    this.nip,
    this.department,
    this.unit,
    this.position,
    this.hasFaceEnrollment = false,
  });

  final int id;
  final String name;
  final String? username;
  final String? email;
  final String? noHp;
  final String? alamat;
  final String? nip;
  final String? department;
  final String? unit;
  final String? position;
  final bool hasFaceEnrollment;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '-',
      username: json['username'] as String?,
      email: json['email'] as String?,
      noHp: json['no_hp'] as String?,
      alamat: json['alamat'] as String?,
      nip: json['nip'] as String?,
      department: json['department'] as String?,
      unit: json['unit'] as String?,
      position: json['position'] as String?,
      hasFaceEnrollment: json['has_face_enrollment'] as bool? ?? false,
    );
  }
}
