import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';
import '../landing_content.dart';
import 'property_photo_tile.dart';

/// Website-only editorial sections. Copy describes photographs and the inquiry
/// process; it does not assert unverified amenities, prices or availability.
class ResidenceNarrativeSection extends StatelessWidget {
  const ResidenceNarrativeSection({
    super.key,
    required this.onGallery,
    required this.onOpenRoom,
  });

  final VoidCallback onGallery;
  final VoidCallback onOpenRoom;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 860;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _EditorialLabel('01 / THE RESIDENCE'),
              const SizedBox(height: 22),
              Text(
                'A closer look at\nwhere life happens.',
                style: _sectionTitle(sideBySide ? 54 : 38),
              ),
              const SizedBox(height: 24),
              const _EditorialBody(
                'Start with the actual spaces. Explore photographs of rooms, '
                'the courtyard, and shared areas before reaching out to staff '
                'about the details that matter to you.',
              ),
              const SizedBox(height: 29),
              const Divider(color: WebPalette.border, height: 1),
              const SizedBox(height: 18),
              const _NumberedNote('01', 'See the property through real photos.'),
              const SizedBox(height: 15),
              const _NumberedNote('02', 'Confirm current arrangements with staff.'),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.arrow_outward, size: 18),
                label: const Text('Explore the photographs'),
                style: TextButton.styleFrom(foregroundColor: WebPalette.plum),
              ),
            ],
          );
          final photo = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PropertyPhotoTile(
                photo: LandingContent.photos[1],
                height: sideBySide ? 560 : 350,
                showCaption: false,
                onOpen: onOpenRoom,
              ),
              const SizedBox(height: 13),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'CARMELITA / ROOM PERSPECTIVE',
                      softWrap: true,
                      style: TextStyle(
                        color: WebPalette.plum,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.north_east, size: 17, color: WebPalette.plum),
                ],
              ),
            ],
          );
          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [photo, const SizedBox(height: 30), copy],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 9, child: copy),
              const SizedBox(width: 62),
              Expanded(flex: 11, child: photo),
            ],
          );
        },
      );
}

class RoomStoriesSection extends StatelessWidget {
  const RoomStoriesSection({
    super.key,
    required this.onOpenPhoto,
    required this.onInquire,
  });

  final ValueChanged<PropertyPhoto> onOpenPhoto;
  final VoidCallback onInquire;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final mainPhoto = LandingContent.photos[1];
          final detailPhoto = LandingContent.photos[2];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _EditorialLabel('02 / INSIDE CARMELITA'),
              const SizedBox(height: 17),
              wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Text('Real rooms.\nCloser details.',
                              style: _sectionTitle(56)),
                        ),
                        const SizedBox(width: 30),
                        const Expanded(
                          flex: 4,
                          child: _EditorialBody(
                            'Look closely at the layout and the details. '
                            'Staff can confirm current bed-space availability '
                            'and pricing when you inquire.',
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Real rooms.\nCloser details.',
                            style: _sectionTitle(38)),
                        const SizedBox(height: 17),
                        const _EditorialBody(
                          'Look closely at the layout and the details. Staff '
                          'can confirm current bed-space availability and '
                          'pricing when you inquire.',
                        ),
                      ],
                    ),
              const SizedBox(height: 34),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _photoWithNote(
                        mainPhoto,
                        height: 545,
                        note: '01 / THE ROOM LAYOUT',
                      ),
                    ),
                    const SizedBox(width: 19),
                    Expanded(
                      flex: 4,
                      child: _photoWithNote(
                        detailPhoto,
                        height: 350,
                        note: '02 / THE STUDY CORNER',
                      ),
                    ),
                  ],
                )
              else ...[
                _photoWithNote(mainPhoto, height: 330, note: '01 / THE ROOM LAYOUT'),
                const SizedBox(height: 26),
                _photoWithNote(detailPhoto, height: 260, note: '02 / THE STUDY CORNER'),
              ],
              const SizedBox(height: 29),
              const Divider(color: WebPalette.border, height: 1),
              const SizedBox(height: 14),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 24,
                runSpacing: 9,
                children: [
                  const Text('MORE QUESTIONS ABOUT A ROOM?', style: TextStyle(
                    color: WebPalette.plum,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  )),
                  TextButton.icon(
                    onPressed: onInquire,
                    icon: const Icon(Icons.arrow_outward, size: 18),
                    label: const Text('Ask the team'),
                    style: TextButton.styleFrom(foregroundColor: WebPalette.plum),
                  ),
                ],
              ),
            ],
          );
        },
      );

  Widget _photoWithNote(PropertyPhoto photo, {
    required double height,
    required String note,
  }) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PropertyPhotoTile(
            photo: photo,
            height: height,
            showCaption: false,
            onOpen: () => onOpenPhoto(photo),
          ),
          const SizedBox(height: 13),
          Text(note, style: const TextStyle(
            color: WebPalette.plum,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          )),
        ],
      );
}

/// Prospective-visitor information, not a promise of app access or live
/// monitoring for guardians. Public contact remains the existing staff route.
class StudentGuardianSection extends StatelessWidget {
  const StudentGuardianSection({super.key, required this.onInquire});

  final VoidCallback onInquire;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EditorialLabel('05 / BEFORE YOU MOVE IN'),
              const SizedBox(height: 17),
              Text('Different questions.\nOne place to start.',
                  style: _sectionTitle(wide ? 51 : 37)),
              const SizedBox(height: 16),
              const _EditorialBody(
                'Whether you are exploring a place to stay or helping '
                'someone prepare, start with the actual property and ask '
                'staff to verify details before making arrangements.',
              ),
            ],
          );
          final audience = wide
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _AudienceNote(
                      label: 'FOR PROSPECTIVE TENANTS',
                      number: '01',
                      heading: 'Picture your space.',
                      body: 'Browse the real room and property photos, then ask '
                          'which rooms or bed spaces are currently available.',
                    )),
                    SizedBox(width: 45),
                    Expanded(child: _AudienceNote(
                      label: 'FOR PARENTS & GUARDIANS',
                      number: '02',
                      heading: 'Get the details directly.',
                      body: 'Ask staff about the current house rules, '
                          'arrangements, rates, and viewing process.',
                    )),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AudienceNote(
                      label: 'FOR PROSPECTIVE TENANTS',
                      number: '01',
                      heading: 'Picture your space.',
                      body: 'Browse the real room and property photos, then ask '
                          'which rooms or bed spaces are currently available.',
                    ),
                    SizedBox(height: 30),
                    _AudienceNote(
                      label: 'FOR PARENTS & GUARDIANS',
                      number: '02',
                      heading: 'Get the details directly.',
                      body: 'Ask staff about the current house rules, '
                          'arrangements, rates, and viewing process.',
                    ),
                  ],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              SizedBox(height: wide ? 55 : 35),
              audience,
              const SizedBox(height: 26),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onInquire,
                  icon: const Icon(Icons.arrow_outward, size: 18),
                  label: const Text('Ask staff about the details'),
                  style: TextButton.styleFrom(foregroundColor: WebPalette.plum),
                ),
              ),
            ],
          );
        },
      );
}

class _AudienceNote extends StatelessWidget {
  const _AudienceNote({
    required this.label,
    required this.number,
    required this.heading,
    required this.body,
  });

  final String label;
  final String number;
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 23, top: 5, bottom: 8),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: WebPalette.plum, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$number / $label', style: const TextStyle(
              color: WebPalette.plum,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            )),
            const SizedBox(height: 18),
            Text(heading, style: _sectionTitle(27)),
            const SizedBox(height: 13),
            _EditorialBody(body),
          ],
        ),
      );
}

class _EditorialLabel extends StatelessWidget {
  const _EditorialLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label,
        style: const TextStyle(
          color: WebPalette.plumLight,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      );
}

class _EditorialBody extends StatelessWidget {
  const _EditorialBody(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(value,
        style: const TextStyle(
          color: WebPalette.muted,
          fontSize: 16,
          height: 1.65,
        ),
      );
}

class _NumberedNote extends StatelessWidget {
  const _NumberedNote(this.number, this.value);
  final String number;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(
            color: WebPalette.plum,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          )),
          const SizedBox(width: 15),
          Expanded(child: Text(value, style: const TextStyle(
            color: WebPalette.muted,
            fontSize: 14,
            height: 1.45,
          ))),
        ],
      );
}

TextStyle _sectionTitle(double size) => TextStyle(
      color: WebPalette.ink,
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.1,
      letterSpacing: size > 50 ? -2.4 : -1.1,
    );
