import 'package:bridalglow_mobile/models/dress_category.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class DressCategoryProvider extends BaseProvider<DressCategory> {
  DressCategoryProvider() : super('DressCategory');

  @override
  DressCategory fromJson(dynamic json) =>
      DressCategory.fromJson(json as Map<String, dynamic>);
}
