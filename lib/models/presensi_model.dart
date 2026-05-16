class PresensiModel {
  const PresensiModel({
    required this.id,
    this.tanggal,
    this.jamMasuk,
    this.jamKeluar,
    this.status,
    this.statusPulang,
    this.keterangan,
  });

  final int id;
  final String? tanggal;
  final String? jamMasuk;
  final String? jamKeluar;
  final String? status;
  final String? statusPulang;
  final String? keterangan;

  factory PresensiModel.fromJson(Map<String, dynamic> json) {
    return PresensiModel(
      id: json['id'] as int? ?? 0,
      tanggal: json['tanggal'] as String?,
      jamMasuk: json['jam_masuk'] as String?,
      jamKeluar: json['jam_keluar'] as String?,
      status: json['status'] as String?,
      statusPulang: json['status_pulang'] as String?,
      keterangan: json['keterangan'] as String?,
    );
  }
}
