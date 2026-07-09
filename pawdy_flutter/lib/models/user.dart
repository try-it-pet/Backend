class User {
  final int id;
  final String provider; // kakao | dev
  final String nickname;
  final String? profileImage;

  const User({
    required this.id,
    required this.provider,
    required this.nickname,
    this.profileImage,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        provider: j['provider'] as String? ?? 'dev',
        nickname: j['nickname'] as String? ?? '집사',
        profileImage: j['profile_image'] as String?,
      );

  bool get isKakao => provider == 'kakao';
}

class Pet {
  final int id;
  final String name;
  final String species; // dog|cat|rabbit
  final String? breed;
  final double? weightKg;
  final double? chestCm;
  final double? neckCm;
  final double? backCm;
  final String? image;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.weightKg,
    this.chestCm,
    this.neckCm,
    this.backCm,
    this.image,
  });

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        species: j['species'] as String? ?? 'dog',
        breed: j['breed'] as String?,
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        chestCm: (j['chest_cm'] as num?)?.toDouble(),
        neckCm: (j['neck_cm'] as num?)?.toDouble(),
        backCm: (j['back_cm'] as num?)?.toDouble(),
        image: j['image'] as String?,
      );
}


class Stats {
  final int orders;
  final int likes;
  final int fittings;
  const Stats({this.orders = 0, this.likes = 0, this.fittings = 0});

  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        fittings: (j['fittings'] as num?)?.toInt() ?? 0,
      );
}
