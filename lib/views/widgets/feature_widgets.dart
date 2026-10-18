import '../../core/config/app_features.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';

class FloorPlanCanvas extends StatefulWidget {
  const FloorPlanCanvas({
    this.onLocationSelected,
    this.monitorMode = false,
    super.key,
  });

  final ValueChanged<String>? onLocationSelected;
  final bool monitorMode;

  @override
  State<FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends State<FloorPlanCanvas> {
  String selected = 'Room 204';

  final List<String> rooms = const [
    'Room 201',
    'Room 202',
    'Room 203',
    'Room 204',
    'Pantry',
    'Lounge',
  ];

  @override
  Widget build(BuildContext context) {
    if (!AppFeatures.floorPlanEnabled)
      return const Text('Floor plan is currently disabled.');
    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 330;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Second Floor',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusPill(
                      widget.monitorMode
                          ? '2 active reports'
                          : 'Tap a location',
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Second Floor',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  StatusPill(
                    widget.monitorMode ? '2 active reports' : 'Tap a location',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(18),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final columns = constraints.maxWidth < 300 ? 2 : 3;
                final itemWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                        columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: rooms.map((room) {
                    final isSelected = room == selected;
                    final hasIssue = widget.monitorMode &&
                        (room == 'Room 204' || room == 'Pantry');

                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(14),
                        ),
                        onTap: () {
                          setState(() => selected = room);
                          widget.onLocationSelected?.call(room);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 180,
                          ),
                          curve: Curves.easeOutCubic,
                          constraints: const BoxConstraints(
                            minHeight: 72,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .12)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(14),
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  room,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (hasIssue)
                                const Positioned(
                                  right: 0,
                                  top: 0,
                                  child: CircleAvatar(
                                    radius: 6,
                                    backgroundColor: AppColors.warning,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Selected: $selected',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.monitorMode
                ? 'Markers represent frontend sample maintenance locations.'
                : 'This location value is ready to map to backend room/area records.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField(
      {required this.label,
      this.hint,
      this.controller,
      this.maxLines = 1,
      this.keyboardType,
      super.key});
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final int maxLines;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint)),
      ]);
}
