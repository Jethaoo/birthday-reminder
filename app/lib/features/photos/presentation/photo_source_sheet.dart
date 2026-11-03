import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';

/// Asks where a new photo should come from. Returns null when the sheet is
/// dismissed; the caller then leaves the screen untouched.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  final palette = paletteOf(context);
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.sheetRadius),
      ),
    ),
    builder: (_) => _PhotoSourceSheet(palette: palette),
  );
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a photo',
            style: text.titleMedium?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You can crop it before it is saved.',
            style: text.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          _SourceOption(
            palette: palette,
            icon: Icons.photo_camera_outlined,
            title: 'Take a photo',
            subtitle: 'Open the camera',
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          _SourceOption(
            palette: palette,
            icon: Icons.photo_library_outlined,
            title: 'Choose from library',
            subtitle: 'Use a photo on this device',
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: palette.textSecondary,
              minimumSize: const Size(0, AppSpacing.minTouchTarget),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.softGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: palette.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyMedium?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}
