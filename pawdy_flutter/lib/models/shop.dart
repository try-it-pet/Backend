class Shop {
  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final int ownerId;
  final String createdAt;

  const Shop({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    required this.ownerId,
    required this.createdAt,
  });

  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        logoUrl: j['logo_url'] as String?,
        ownerId: j['owner_id'] as int,
        createdAt: j['created_at'] as String? ?? '',
      );
}
