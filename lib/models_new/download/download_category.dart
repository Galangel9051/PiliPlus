class DownloadCategory {
  final String id;
  String name;

  DownloadCategory({
    required this.id,
    required this.name,
  });

  factory DownloadCategory.fromJson(Map<String, dynamic> json) =>
      DownloadCategory(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is DownloadCategory) {
      return id == other.id;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;
}
