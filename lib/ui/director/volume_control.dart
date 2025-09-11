import 'package:flutter/material.dart';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:flutter_video_editor_app/service/director_service.dart';
import 'package:flutter_video_editor_app/service_locator.dart';

class VolumeSliderPopup extends StatefulWidget {
  final int layerIndex;
  final int assetIndex;
  final Asset asset;

  const VolumeSliderPopup({
    super.key,
    required this.layerIndex,
    required this.assetIndex,
    required this.asset,
  });

  @override
  State<VolumeSliderPopup> createState() => _VolumeSliderPopupState();
}

class _VolumeSliderPopupState extends State<VolumeSliderPopup> {
  final directorService = locator.get<DirectorService>();
  late double currentVolume;
  bool isSliding = false;

  @override
  void initState() {
    super.initState();
    currentVolume = widget.asset.volume ?? 1.0;
  }

  void _updateVolume(double newVolume) {
    setState(() {
      currentVolume = newVolume;
    });

    // Update the asset volume
    directorService.updateAssetVolume(
      widget.layerIndex,
      widget.assetIndex,
      newVolume,
    );
  }

  void _onSliderStart(double value) {
    setState(() {
      isSliding = true;
    });
  }

  void _onSliderEnd(double value) {
    setState(() {
      isSliding = false;
    });
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0.0) {
      return Icons.volume_off;
    } else if (volume < 0.3) {
      return Icons.volume_mute;
    } else if (volume < 0.7) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  Color _getVolumeIconColor(double volume) {
    if (volume == 0.0) {
      return Colors.red;
    } else if (volume < 0.3) {
      return Colors.orange;
    } else if (volume < 0.7) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 180, // Vertical layout
        width: 50, // Narrower for vertical design
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Percentage display (shown when sliding or always visible)
            AnimatedOpacity(
              opacity: isSliding ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(currentVolume * 100).round()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Vertical slider
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: RotatedBox(
                  quarterTurns: 3, // Rotate to make it vertical
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _getVolumeIconColor(currentVolume),
                      inactiveTrackColor: Colors.grey[700],
                      thumbColor: _getVolumeIconColor(currentVolume),
                      overlayColor: _getVolumeIconColor(
                        currentVolume,
                      ).withValues(alpha: 0.3),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 15,
                      ),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: currentVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: _updateVolume,
                      onChangeStart: _onSliderStart,
                      onChangeEnd: _onSliderEnd,
                    ),
                  ),
                ),
              ),
            ),

            // Volume icon at the bottom
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _getVolumeIconColor(
                  currentVolume,
                ).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _getVolumeIcon(currentVolume),
                color: _getVolumeIconColor(currentVolume),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VolumeIndicatorWidget extends StatelessWidget {
  final double? volume;
  final VoidCallback onTap;

  const VolumeIndicatorWidget({
    super.key,
    required this.volume,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveVolume = volume ?? 1.0;

    IconData iconData;
    Color iconColor;

    if (effectiveVolume == 0.0) {
      iconData = Icons.volume_off;
      iconColor = Colors.red;
    } else if (effectiveVolume < 0.3) {
      iconData = Icons.volume_mute;
      iconColor = Colors.orange;
    } else if (effectiveVolume < 0.7) {
      iconData = Icons.volume_down;
      iconColor = Colors.blue;
    } else {
      iconData = Icons.volume_up;
      iconColor = Colors.green;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(iconData, size: 16, color: iconColor),
      ),
    );
  }
}
