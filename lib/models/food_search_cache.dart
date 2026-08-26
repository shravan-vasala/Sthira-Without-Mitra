import 'package:isar/isar.dart';

part 'food_search_cache.g.dart';

@collection
class FoodSearchCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  final String normalizedQuery;
  final String cachedResponseJson;

  FoodSearchCache({
    required this.normalizedQuery,
    required this.cachedResponseJson,
  });
}
