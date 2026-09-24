class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.timezone,
  });

  final String id;
  final String name;
  final String email;
  final String timezone;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        timezone: json['timezone'] as String? ?? 'UTC',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'timezone': timezone,
      };

  AppUser copyWith({String? name, String? email, String? timezone}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        timezone: timezone ?? this.timezone,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
