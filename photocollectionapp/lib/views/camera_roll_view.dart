import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../viewmodels/camera_roll_viewmodel.dart';
import '../viewmodels/image_preview_viewmodel.dart';
import '../viewmodels/photos_viewmodel.dart';
import '../widgets/collapsible_date_section.dart';
import '../widgets/photo_view_mode_toggle.dart';
import 'image_preview_view.dart';

class CameraRollView extends StatelessWidget {
  const CameraRollView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CameraRollViewBody();
  }
}

class _CameraRollViewBody extends StatefulWidget {
  const _CameraRollViewBody();

  @override
  State<_CameraRollViewBody> createState() => _CameraRollViewBodyState();
}

class _CameraRollViewBodyState extends State<_CameraRollViewBody> {
  @override
  void initState() {
    super.initState();

    // Reload every time this page is mounted so newly added local photos appear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CameraRollViewModel>().loadPhotos();
    });
  }

  // A dropdown menu for additional selection tools.
  Widget _buildSelectionTitle(BuildContext context, int selected) {
    final vm = context.watch<CameraRollViewModel>();

    return PopupMenuButton<SelectionAction>(
      tooltip: 'Selection options',
      onSelected: (action) => vm.selectionAction(action),
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: SelectionAction.selectNotUploaded,
              child: Text('Select not uploaded'),
            ),
            const PopupMenuItem(
              value: SelectionAction.selectUploaded,
              child: Text('Select uploaded'),
            ),
            const PopupMenuItem(
              value: SelectionAction.selectInvert,
              child: Text('Invert selection'),
            ),
            const PopupMenuItem(
              value: SelectionAction.selectAll,
              child: Text('Select all'),
            ),
            const PopupMenuItem(
              value: SelectionAction.selectNone,
              child: Text('Select none'),
            ),
          ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$selected selected'),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  // The selection bar is only visible while in selection mode.
  AppBar _buildSelectionBar(BuildContext context) {
    final vm = context.watch<CameraRollViewModel>();
    final count = vm.selectedItems.length;
    return AppBar(
      centerTitle: false,
      title: _buildSelectionTitle(context, count),
      actions: [
        // Upload button
        IconButton(
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: () async {
            if (count < 1) return;

            try {
              final selectedGroup = await _selectUploadGroup(context);
              if (!context.mounted || selectedGroup == null) return;

              /*dep.
              final confirmed = await showConfirmationDialog(
                context: context,
                title: 'Upload photos?',
                message:
                    'Upload the selected photos and share them with group ${selectedGroup.name}?',
                confirmText: 'Upload',
              );
              if (confirmed) {}
              */
              await vm.uploadSelectedPhotos(groupId: selectedGroup.id);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed. Please try again. Details: $e'),
                ),
              );
            }
          },
        ),

        // Delete button (only in selection mode)
        IconButton(
          icon: const Icon(Icons.delete_forever_rounded),
          onPressed: () async {
            if (count < 1) return;
            final confirmed = await showConfirmationDialog(
              context: context,
              title: 'Delete photos?',
              message:
                  'Permanently delete the selected photos from your device.',
              confirmText: 'Delete',
              isDestructive: true,
            );
            if (confirmed) {
              vm.deleteSelectedPhotosLocally();
            }
          },
        ),

        // Selection mode toggle button (ONLY when not uploading)
        IconButton(
          onPressed: () => vm.exitSelectionMode(),
          tooltip: 'Unselect photos',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(Icons.close, key: ValueKey(vm.isSelectionMode)),
          ),
        ),
      ],
    );
  }

  // The app bar when nothing is selected.
  AppBar _buildNormalBar(BuildContext context) {
    final vm = context.watch<CameraRollViewModel>();
    return AppBar(
      centerTitle: false,
      title: const Text('My photos'),
      actions: [
        PhotoViewModeToggle(
          value: vm.groupByDate,
          onChanged: (value) => vm.setGroupByDate(value),
        ),

        // Either show upload indicator or button to enter select mode.
        vm.isUploading
            ? IconButton(
              onPressed: null,
              tooltip: 'Upload is in progress...',
              icon: AnimatedUploadIcon(),
            )
            : IconButton(
              onPressed: () => vm.enterSelectionMode(),
              tooltip: 'Select photos',
              icon: Icon(Icons.check_circle_outline),
            ),
      ],
    );
  }

  Stack _buildItem(BuildContext context, PhotoItem item, bool isSelected) {
    final iconColor = Theme.of(context).colorScheme.onPrimary;

    return Stack(
      children: [
        Positioned.fill(
          child: Image(image: item.photo.getMini(), fit: BoxFit.cover),
        ),
        if (isSelected) Container(color: Colors.black.withAlpha(96)),
        if (isSelected)
          const Positioned(
            bottom: 4,
            right: 4,
            child: Icon(Icons.check_circle, color: Colors.white),
          ),
        //if (item.isMine) Positioned(top: 4, left: 4, child: Icon(Icons.person, color: iconColor)),
        if (item.isUploaded)
          Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.cloud_done, color: iconColor),
          ),
      ],
    );
  }

  void _onItemTap(BuildContext context, PhotoItem item) {
    final vm = context.read<CameraRollViewModel>();
    if (vm.isSelectionMode) {
      vm.toggleSelected(item);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChangeNotifierProvider(
                create: (_) => ImagePreviewViewModel(),
                child: ImagePreviewView(photo: item.photo),
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CameraRollViewModel>();
    //dep. final hasSelection = vm.selectedItems.isNotEmpty;
    //dep. String titleText = vm.titleText;

    final sections = CameraRollViewModel.groupPhotosByDate(vm.items);

    final content =
        vm.groupByDate
            ? ListView(
              children: [
                for (final section in sections)
                  CollapsibleDateSection<PhotoItem>(
                    title: section.title,
                    items: section.items,
                    isSelectionMode: vm.isSelectionMode,
                    selectedItems: vm.selectedItems,
                    isUploading: vm.isUploading,
                    onToggleSelection: (item) => vm.toggleSelected(item),
                    onSelectAll: () => vm.selectItems(section.items),
                    onDeselectAll: () => vm.deselectItems(section.items),
                    onItemTap: (item) => _onItemTap(context, item),
                    onItemLongPress: (item) {
                      vm.enterSelectionMode();
                      vm.toggleSelected(item);
                    },
                    itemBuilder: _buildItem,
                    itemLabelSingular: 'photo',
                    itemLabelPlural: 'photos',
                  ),
              ],
            )
            : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: vm.items.length,
              itemBuilder: (context, index) {
                final item = vm.items[index];
                final isSelected = vm.selectedItems.contains(item);
                return GestureDetector(
                  onTap: () => _onItemTap(context, item),
                  onLongPress: () {
                    vm.enterSelectionMode();
                    vm.toggleSelected(item);
                  },
                  child: _buildItem(context, item, isSelected),
                );
              },
            );

    return Scaffold(
      appBar:
          vm.isSelectionMode
              ? _buildSelectionBar(context)
              : _buildNormalBar(context),
      body:
          vm.items.isEmpty
              ? Center(child: CircularProgressIndicator())
              : content,
    );
  }

  Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    // Dialog respects dark/light mode and maintains readability.
    final theme = Theme.of(context);
    final tcs = theme.colorScheme;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must choose
      builder: (context) {
        return AlertDialog(
          backgroundColor: tcs.surface,
          title: Text(title, style: theme.textTheme.titleLarge),
          content: Text(message, style: theme.textTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: tcs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: isDestructive ? tcs.error : tcs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<Group?> _showGroupSelectionDialog(
    BuildContext context,
    List<Group> groups,
  ) async {
    // Expecting groups to contain at least one item, otherwise this function should not be called.
    String? selectedGroupId = groups.first.id;
    const String dialogTitle = 'Upload photos?';

    return showDialog<Group?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(dialogTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload the selected photos and share them with a group.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: RadioGroup<String>(
                          groupValue: selectedGroupId,
                          onChanged: (value) {
                            setState(() {
                              selectedGroupId = value;
                            });
                          },
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              return RadioListTile<String>(
                                value: group.id,
                                title: Text(group.name),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final selectedGroup = groups.firstWhere(
                      (group) => group.id == selectedGroupId,
                      orElse: () => groups.first,
                    );
                    Navigator.pop(dialogContext, selectedGroup);
                  },
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Group?> _selectUploadGroup(BuildContext context) async {
    final vm = context.read<CameraRollViewModel>();
    List<Group> groups;
    try {
      groups = await vm.storageService.groupService.getGroupsForUser(vm.userId);
    } catch (_) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load groups for upload.'),
        ),
      );
      return null;
    }
    const String dialogTitle = 'Upload photos?';

    if (!context.mounted) return null;

    if (groups.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(dialogTitle),
            content: const Text(
              'To upload photos you must be member of a group first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
      return null;
    }

    // If groups contain at least one item, let the user select group and confirm upload.
    return _showGroupSelectionDialog(context, groups);
  }
}

class AnimatedUploadIcon extends StatefulWidget {
  const AnimatedUploadIcon({super.key});

  @override
  State<AnimatedUploadIcon> createState() => _AnimatedUploadIconState();
}

class _AnimatedUploadIconState extends State<AnimatedUploadIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1500),
  )..repeat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tcs = theme.colorScheme;

    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 2,
            child: Icon(
              Icons.cloud,
              size: 22,
              color: tcs.onSurface.withAlpha(127),
            ),
          ),

          AnimatedBuilder(
            animation: _controller,
            child: Icon(
              Icons.photo, //.upload, //north, //_rounded,//.arrow_upward,
              size: 14,
              color: tcs.onSurface, // tcs.primary, // strong contrast
            ),
            builder: (_, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  12 - 12 * _controller.value, // starts lower, moves upward
                ),
                child: Opacity(opacity: 1 - _controller.value, child: child),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
