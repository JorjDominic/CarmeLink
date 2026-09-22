/// Locations shared as Google Maps place links for Carmelita and NU Baliwag.
/// These are place pins; staff should still confirm the physical entrance.
/// The embedded map uses OpenStreetMap, without a Google Maps API key.
abstract final class LocationMapConfig {
  /// Coordinates from the Google Maps place URL provided for Carmelita.
  static const propertyLatitude = 14.9493894;
  static const propertyLongitude = 120.8845848;
  static const universityLatitude = 14.9594505;
  static const universityLongitude = 120.8899354;

  /// Place URLs supplied by the team. These are NOT iframe embed URLs.
  static const propertyMapsUrl = 'https://maps.app.goo.gl/wKXQG8GzEx9jiyDV9';
  static const universityMapsUrl = 'https://maps.app.goo.gl/Gc5BZtcC4C8VmuUB9';

  /// Marker at the shared Google Maps place pin. The entrance is not independently verified.
  static const verifiedEmbedUrl =
      'https://www.openstreetmap.org/export/embed.html?'
      'bbox=120.8805848%2C14.9453894%2C120.8885848%2C14.9533894'
      '&layer=mapnik&marker=14.9493894%2C120.8845848';

  // Fallback, used only when the place marker is missing/invalid.
  static const neighborhoodEmbedUrl =
      'https://www.openstreetmap.org/export/embed.html?'
      'bbox=120.8795%2C14.9463%2C120.8995%2C14.9583&layer=mapnik';

  static bool isApprovedEmbedUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.host == 'www.google.com' || uri.host == 'google.com') {
      return uri.path == '/maps/embed' ||
          uri.path.startsWith('/maps/embed/');
    }
    if (uri.host == 'www.openstreetmap.org') {
      return uri.path == '/export/embed.html' &&
          uri.queryParameters.containsKey('marker');
    }
    return false;
  }

  /// Format check, not independent confirmation of the entrance coordinates.
  static bool get hasVerifiedPin => isApprovedEmbedUrl(verifiedEmbedUrl);

  static String get embedUrl =>
      hasVerifiedPin ? verifiedEmbedUrl : neighborhoodEmbedUrl;

  static const propertyAddress =
      'Carmelita’s Dormitory, 0415 Dr Luis Reyes St., Brgy. Concepcion, '
      'Baliwag, Bulacan';

  /// Leaving out origin lets Google Maps use the visitor's location when available.
  static Uri get directionsUri => Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$propertyLatitude,$propertyLongitude',
      });

  /// Opens the exact NU Baliwag place page shared by the team.
  static Uri get universityUri => Uri.parse(universityMapsUrl);

  /// Separate Google Maps route from the dormitory's shared place pin to NU.
  static Uri get dormToUniversityUri =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': '$propertyLatitude,$propertyLongitude',
        'destination': '$universityLatitude,$universityLongitude',
      });
}
