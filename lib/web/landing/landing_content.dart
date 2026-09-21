/// Approved photography curated from the owner's supplied Facebook image ZIP.
/// The labels describe visible locations; they do not imply live availability.
enum PropertyCategory { rooms, property, shared }

class PropertyPhoto {
  const PropertyPhoto({
    required this.path,
    required this.title,
    required this.description,
    required this.category,
  });

  final String path;
  final String title;
  final String description;
  final PropertyCategory category;
}

abstract final class LandingContent {
  static const facebookUrl =
      'https://www.facebook.com/profile.php?id=61562079845434';
  static const mapsUrl =
      'https://maps.app.goo.gl/wKXQG8GzEx9jiyDV9';

  static const photos = <PropertyPhoto>[
    PropertyPhoto(
      path: 'assets/web/photos/courtyard.jpg',
      title: 'The courtyard',
      description: 'A view of the residence',
      category: PropertyCategory.property,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/room_overview.jpg',
      title: 'Inside a room',
      description: 'A look at the bunk-bed layout',
      category: PropertyCategory.rooms,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/study_corner.jpg',
      title: 'Study corner',
      description: 'A desk beside the window',
      category: PropertyCategory.rooms,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/outdoor_seating.jpg',
      title: 'Outdoor seating',
      description: 'A shared outdoor area',
      category: PropertyCategory.shared,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/bunk_corner.jpg',
      title: 'Bunk-bed detail',
      description: 'A closer look inside',
      category: PropertyCategory.rooms,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/wardrobe_space.jpg',
      title: 'Storage and room',
      description: 'Wardrobe and bed arrangement',
      category: PropertyCategory.rooms,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/room_detail.jpg',
      title: 'Room perspective',
      description: 'Another view of the room',
      category: PropertyCategory.rooms,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/property_exterior.jpg',
      title: 'The residence',
      description: 'Exterior and courtyard view',
      category: PropertyCategory.property,
    ),
    PropertyPhoto(
      path: 'assets/web/photos/bunk_layout.jpg',
      title: 'Room and bunk layout',
      description: 'An additional room perspective',
      category: PropertyCategory.rooms,
    ),
  ];
}
