import 'package:bridalglow_mobile/models/dress_tag.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class DressTagProvider extends BaseProvider<DressTag> {
  DressTagProvider() : super('DressTag');

  @override
  DressTag fromJson(dynamic json) =>
      DressTag.fromJson(json as Map<String, dynamic>);
}
