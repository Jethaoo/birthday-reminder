class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.timezone,
    this.photoUrl,
    this.birthdayMonth,
    this.birthdayDay,
    this.birthYear,
  });

  final String id;
  final String name;
  final String email;
  final String timezone;
  final String? photoUrl;
  final int? birthdayMonth;
  final int? birthdayDay;
  final int? birthYear;

  bool get hasBirthday => birthdayMonth != null && birthdayDay != null;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    timezone: json['timezone'] as String? ?? 'UTC',
    photoUrl: json['photoUrl'] as String?,
    birthdayMonth: json['birthdayMonth'] as int?,
    birthdayDay: json['birthdayDay'] as int?,
    birthYear: json['birthYear'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'timezone': timezone,
    'photoUrl': photoUrl,
    'birthdayMonth': birthdayMonth,
    'birthdayDay': birthdayDay,
    'birthYear': birthYear,
  };

  AppUser copyWith({
    String? name,
    String? email,
    String? timezone,
    String? photoUrl,
    bool clearPhoto = false,
    int? birthdayMonth,
    int? birthdayDay,
    int? birthYear,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    timezone: timezone ?? this.timezone,
    photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
    birthdayMonth: birthdayMonth ?? this.birthdayMonth,
    birthdayDay: birthdayDay ?? this.birthdayDay,
    birthYear: birthYear ?? this.birthYear,
  );

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
