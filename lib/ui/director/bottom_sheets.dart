import 'package:flutter/material.dart';
import 'package:flutter_video_editor/model/model.dart';
import 'package:flutter_video_editor/service/director/generator.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:flutter_video_editor/ui/director/progress_dialog.dart';
import 'package:flutter_video_editor/ui/generated_video_list.dart';

class AddMediaBottomSheet extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Add Media',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            // Media options
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MediaTile(
                  icon: Icons.videocam,
                  title: 'Add Video',
                  subtitle: 'Import video from gallery',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    directorService.add(AssetType.video);
                  },
                ),
                _MediaTile(
                  icon: Icons.image,
                  title: 'Add Image',
                  subtitle: 'Import image from gallery',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    directorService.add(AssetType.image);
                  },
                ),
                _MediaTile(
                  icon: Icons.audiotrack,
                  title: 'Add Audio',
                  subtitle: 'Import audio track',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    directorService.add(AssetType.audio);
                  },
                ),
                _MediaTile(
                  icon: Icons.title,
                  title: 'Add Title',
                  subtitle: 'Create text overlay',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    directorService.add(AssetType.text);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class SaveVideoBottomSheet extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ProgressDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Save Video',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            // Export options
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ExportTile(
                  icon: Icons.hd,
                  title: 'Full HD (1080p)',
                  subtitle: 'Best quality • 1920x1080',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    directorService.generateVideo(
                      directorService.layers,
                      VideoResolution.fullHd,
                    );
                    _showProgressDialog(context);
                  },
                ),
                _ExportTile(
                  icon: Icons.hd,
                  title: 'HD (720p)',
                  subtitle: 'Good quality • 1280x720',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    directorService.generateVideo(
                      directorService.layers,
                      VideoResolution.hd,
                    );
                    _showProgressDialog(context);
                  },
                ),
                _ExportTile(
                  icon: Icons.sd,
                  title: 'SD (360p)',
                  subtitle: 'Fast export • 640x360',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    directorService.generateVideo(
                      directorService.layers,
                      VideoResolution.sd,
                    );
                    _showProgressDialog(context);
                  },
                ),
                const Divider(height: 1, thickness: 1),
                _ExportTile(
                  icon: Icons.video_library,
                  title: 'View Generated Videos',
                  subtitle: 'Browse previously exported videos',
                  color: Colors.purple,
                  showMoreIcon: true,
                  onTap: () {
                    Navigator.pop(context);
                    if (directorService.project == null) {
                      print("Project is null. Cannot navigate to video list");
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GeneratedVideoList(directorService.project!),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MediaTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  _MediaTileState createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                widget.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
              onTap: widget.onTap,
            ),
          ),
        );
      },
    );
  }
}

class _ExportTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool showMoreIcon;

  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.showMoreIcon = false,
  });

  @override
  _ExportTileState createState() => _ExportTileState();
}

class _ExportTileState extends State<_ExportTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                widget.subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              trailing: widget.showMoreIcon
                  ? Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    )
                  : null,
              onTap: widget.onTap,
            ),
          ),
        );
      },
    );
  }
}
