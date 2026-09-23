class Colour {
  final int id;
  final String name;

  Colour({
    required this.id,
    required this.name,
  });

  factory Colour.fromJson(Map<String, dynamic> json) {
    return Colour(
      id: json['id'],
      name: json['name'],
    );
  }
}