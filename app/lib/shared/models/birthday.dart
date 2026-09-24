import 'reminder.dart';

/// Helpers shared by the full and summary birthday shapes.
mixin InitialsMixin {
  String get name;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  /// Stable per-person tint so avatars stay recognisable across screens.
  int get colorSeed => name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
}

/// Lets list screens reuse the summary widget for full records.
extension BirthdaySummaryConversion on Birthday {
  BirthdaySummary toSummary() => BirthdaySummary(
        id: id,
        name: name,
        birthdayMonth: birthdayMonth,
        birthdayDay: birthdayDay,
        birthYear: birthYear,
        relationship: relationship,
        photoUrl: photoUrl,
        nextOccurrence: nextOccurrence,
        daysUntil: daysUntil,
        turningAge: turningAge,
      );
}

class Birthday with InitialsMixin {
  const Birthday({
    required this.id,
    required this.name,
    required this.birthdayMonth,
    required this.birthdayDay,
    this.birthYear,
    this.relationship,
    this.phone,
    this.email,
    this.photoUrl,
    this.notes,
    this.giftIdeas = const [],
    this.reminders = const [],
    required this.nextOccurrence,
    required this.daysUntil,
    this.turningAge,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  @override
  final String name;
  final int birthdayMonth;
  final int birthdayDay;
  final int? birthYear;
  final String? relationship;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String? notes;
  final List<String> giftIdeas;
  final List<Reminder> reminders;
  final DateTime nextOccurrence;
  final int daysUntil;
  final int? turningAge;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Birthday.fromJson(Map<String, dynamic> json) => Birthday(
        id: json['id'] as String,
        name: json['name'] as String,
        birthdayMonth: json['birthdayMonth'] as int,
        birthdayDay: json['birthdayDay'] as int,
        birthYear: json['birthYear'] as int?,
        relationship: json['relationship'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        photoUrl: json['photoUrl'] as String?,
        notes: json['notes'] as String?,
        giftIdeas: (json['giftIdeas'] as List<dynamic>? ?? const []).cast<String>(),
        reminders: (json['reminders'] as List<dynamic>? ?? const [])
            .map((entry) => Reminder.fromJson(entry as Map<String, dynamic>))
            .toList(),
        nextOccurrence: DateTime.parse(json['nextOccurrence'] as String),
        daysUntil: json['daysUntil'] as int? ?? 0,
        turningAge: json['turningAge'] as int?,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null ? null : DateTime.tryParse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthdayMonth': birthdayMonth,
        'birthdayDay': birthdayDay,
        'birthYear': birthYear,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'notes': notes,
        'giftIdeas': giftIdeas,
        'reminders': reminders.map((reminder) => reminder.toJson()).toList(),
        'nextOccurrence': nextOccurrence.toIso8601String().substring(0, 10),
        'daysUntil': daysUntil,
        'turningAge': turningAge,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  /// Payload accepted by `POST` and `PUT /api/birthdays`.
  Map<String, dynamic> toRequest() => {
        'name': name,
        'birthdayMonth': birthdayMonth,
        'birthdayDay': birthdayDay,
        'birthYear': birthYear,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'notes': notes,
        'giftIdeas': giftIdeas,
        'reminders': reminders.map((reminder) => reminder.toRequest()).toList(),
      };

  Birthday copyWith({
    String? name,
    int? birthdayMonth,
    int? birthdayDay,
    int? birthYear,
    bool clearBirthYear = false,
    String? relationship,
    String? phone,
    String? email,
    String? photoUrl,
    String? notes,
    List<String>? giftIdeas,
    List<Reminder>? reminders,
    int? daysUntil,
    DateTime? nextOccurrence,
    int? turningAge,
  }) =>
      Birthday(
        id: id,
        name: name ?? this.name,
        birthdayMonth: birthdayMonth ?? this.birthdayMonth,
        birthdayDay: birthdayDay ?? this.birthdayDay,
        birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
        relationship: relationship ?? this.relationship,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        notes: notes ?? this.notes,
        giftIdeas: giftIdeas ?? this.giftIdeas,
        reminders: reminders ?? this.reminders,
        nextOccurrence: nextOccurrence ?? this.nextOccurrence,
        daysUntil: daysUntil ?? this.daysUntil,
        turningAge: turningAge ?? this.turningAge,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// Lighter shape returned by the Home and Calendar endpoints.
class BirthdaySummary with InitialsMixin {
  const BirthdaySummary({
    required this.id,
    required this.name,
    required this.birthdayMonth,
    required this.birthdayDay,
    this.birthYear,
    this.relationship,
    this.photoUrl,
    required this.nextOccurrence,
    required this.daysUntil,
    this.turningAge,
  });

  final String id;
  @override
  final String name;
  final int birthdayMonth;
  final int birthdayDay;
  final int? birthYear;
  final String? relationship;
  final String? photoUrl;
  final DateTime nextOccurrence;
  final int daysUntil;
  final int? turningAge;

  factory BirthdaySummary.fromJson(Map<String, dynamic> json) => BirthdaySummary(
        id: json['id'] as String,
        name: json['name'] as String,
        birthdayMonth: json['birthdayMonth'] as int,
        birthdayDay: json['birthdayDay'] as int,
        birthYear: json['birthYear'] as int?,
        relationship: json['relationship'] as String?,
        photoUrl: json['photoUrl'] as String?,
        nextOccurrence: DateTime.parse(json['nextOccurrence'] as String),
        daysUntil: json['daysUntil'] as int? ?? 0,
        turningAge: json['turningAge'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthdayMonth': birthdayMonth,
        'birthdayDay': birthdayDay,
        'birthYear': birthYear,
        'relationship': relationship,
        'photoUrl': photoUrl,
        'nextOccurrence': nextOccurrence.toIso8601String().substring(0, 10),
        'daysUntil': daysUntil,
        'turningAge': turningAge,
      };
}
