enum ItemStatus { active, reserved, sold }

class ItemModel {
  final String id;
  final String title;
  final String priceNzd;
  final String location;
  final String imageUrl;
  final bool isSustainable;
  final String category;
  final ItemStatus status;

  const ItemModel({
    required this.id,
    required this.title,
    required this.priceNzd,
    required this.location,
    required this.imageUrl,
    required this.isSustainable,
    required this.category,
    required this.status,
  });

  /// Create a copy of this ItemModel with updated fields.
  ItemModel copyWith({
    String? id,
    String? title,
    String? priceNzd,
    String? location,
    String? imageUrl,
    bool? isSustainable,
    String? category,
    ItemStatus? status,
  }) {
    return ItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      priceNzd: priceNzd ?? this.priceNzd,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      isSustainable: isSustainable ?? this.isSustainable,
      category: category ?? this.category,
      status: status ?? this.status,
    );
  }

  /// Convert to Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'priceNzd': priceNzd,
      'location': location,
      'imageUrl': imageUrl,
      'isSustainable': isSustainable,
      'category': category,
      'status': status.name,
    };
  }

  /// Create from Map.
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] as String,
      title: map['title'] as String,
      priceNzd: map['priceNzd'] as String,
      location: map['location'] as String,
      imageUrl: map['imageUrl'] as String,
      isSustainable: map['isSustainable'] as bool,
      category: map['category'] as String,
      status: ItemStatus.values.byName(map['status'] as String),
    );
  }

  /// JSON serialization helper.
  factory ItemModel.fromJson(Map<String, dynamic> json) =>
      ItemModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemModel &&
        other.id == id &&
        other.title == title &&
        other.priceNzd == priceNzd &&
        other.location == location &&
        other.imageUrl == imageUrl &&
        other.isSustainable == isSustainable &&
        other.category == category &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      priceNzd,
      location,
      imageUrl,
      isSustainable,
      category,
      status,
    );
  }

  @override
  String toString() {
    return 'ItemModel(id: $id, title: $title, priceNzd: $priceNzd, location: $location, imageUrl: $imageUrl, isSustainable: $isSustainable, category: $category, status: $status)';
  }
}
