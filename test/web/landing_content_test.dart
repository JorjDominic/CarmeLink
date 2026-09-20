import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/landing/landing_content.dart';

void main() {
  test('curated photo assets have unique paths and useful descriptions', () {
    final photos = LandingContent.photos;
    expect(photos.length, greaterThanOrEqualTo(8));
    expect(photos.map((photo) => photo.path).toSet().length, photos.length);
    for (final photo in photos) {
      expect(photo.path, startsWith('assets/web/photos/'));
      expect(photo.title, isNotEmpty);
      expect(photo.description, isNotEmpty);
    }
  });

  test('gallery offers rooms, property and shared-space images', () {
    final categories = LandingContent.photos.map((photo) => photo.category).toSet();
    expect(categories, containsAll(PropertyCategory.values));
  });

  test('contact buttons use valid secure external destinations', () {
    for (final url in [LandingContent.facebookUrl, LandingContent.mapsUrl]) {
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    }
  });
}
