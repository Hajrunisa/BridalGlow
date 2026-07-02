import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:bridalglow_desktop/models/dress_image.dart';
import 'package:bridalglow_desktop/providers/auth_provider.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class DressImageProvider extends ChangeNotifier {
  static String get _base => BaseProvider.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthProvider.accessToken != null)
          'Authorization': 'Bearer ${AuthProvider.accessToken}',
      };

  Map<String, String> get _authHeaders => {
        if (AuthProvider.accessToken != null)
          'Authorization': 'Bearer ${AuthProvider.accessToken}',
      };

  void _throwApiError(http.Response response) {
    String? message;
    if (response.body.isNotEmpty) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final errors = data['errors'];
          if (errors is Map && errors.isNotEmpty) {
            message = errors.values
                .expand((v) => v is List ? v : [v])
                .map((e) => e.toString())
                .join('\n');
          }
          message ??=
              data['message']?.toString() ?? data['title']?.toString();
        }
      } catch (_) {}
    }
    throw Exception(message ?? 'Something went wrong, please try again later!');
  }

  Future<List<DressImage>> getByDressId(int dressId) async {
    final response = await http.get(
      Uri.parse('${_base}dress-images?dressId=$dressId'),
      headers: _headers,
    );
    if (response.statusCode < 299) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((e) => DressImage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _throwApiError(response);
    return [];
  }

  /// Multipart upload of an image file.
  Future<DressImage> uploadImage({
    required int dressId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? altText,
    bool isPrimary = false,
    int sortOrder = 0,
  }) async {
    final uri = Uri.parse('${_base}dress-images/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders);

    request.fields['dressId'] = dressId.toString();
    request.fields['isPrimary'] = isPrimary.toString();
    request.fields['sortOrder'] = sortOrder.toString();
    if (altText != null && altText.isNotEmpty) {
      request.fields['altText'] = altText;
    }

    final parts = mimeType.split('/');
    final contentType = parts.length == 2
        ? MediaType(parts[0], parts[1])
        : MediaType('image', 'jpeg');

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: contentType,
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 299) {
      return DressImage.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwApiError(response);
    throw Exception('Upload failed');
  }

  /// Links an external URL as an image.
  Future<DressImage> linkImage({
    required int dressId,
    required String url,
    String? altText,
    int sortOrder = 0,
    bool isPrimary = false,
  }) async {
    final response = await http.post(
      Uri.parse('${_base}dress-images/link'),
      headers: _headers,
      body: jsonEncode({
        'dressId': dressId,
        'url': url,
        if (altText != null && altText.isNotEmpty) 'altText': altText,
        'sortOrder': sortOrder,
        'isPrimary': isPrimary,
      }),
    );
    if (response.statusCode < 299) {
      return DressImage.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwApiError(response);
    throw Exception('Link failed');
  }

  /// Marks the given image as the primary image for its dress.
  Future<DressImage> setPrimary(int id) async {
    final response = await http.put(
      Uri.parse('${_base}dress-images/$id/set-primary'),
      headers: _headers,
    );
    if (response.statusCode < 299) {
      return DressImage.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwApiError(response);
    throw Exception('Set primary failed');
  }

  /// Updates the sort order of an image.
  Future<DressImage> reorderImage(int id, int sortOrder) async {
    final response = await http.put(
      Uri.parse('${_base}dress-images/$id/reorder'),
      headers: _headers,
      body: jsonEncode({'sortOrder': sortOrder}),
    );
    if (response.statusCode < 299) {
      return DressImage.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwApiError(response);
    throw Exception('Reorder failed');
  }

  /// Soft-deletes an image.
  Future<void> deleteImage(int id) async {
    final response = await http.delete(
      Uri.parse('${_base}dress-images/$id'),
      headers: _headers,
    );
    if (response.statusCode >= 299) {
      _throwApiError(response);
    }
  }
}
