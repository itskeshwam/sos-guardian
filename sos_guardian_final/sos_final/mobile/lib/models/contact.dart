class Contact {
  final String id;
  final String name;
  final String phone;
  final String? relationship;

  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship,
  });

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id:           (j['id'] as String?) ?? '',
        name:         (j['name'] as String?) ?? '',
        phone:        (j['phone'] as String?) ?? '',
        relationship: j['relationship'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id':           id,
        'name':         name,
        'phone':        phone,
        'relationship': relationship,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }
}
