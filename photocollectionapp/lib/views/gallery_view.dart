import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/gallery_viewmodel.dart';
import '../viewmodels/image_preview_viewmodel.dart';
import '../viewmodels/photos_viewmodel.dart';
import '../widgets/collapsible_date_section.dart';
import '../widgets/photo_view_mode_toggle.dart';
import 'image_preview_view.dart';

class GalleryView extends StatelessWidget {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _GalleryViewBody();
  }
}

class _GalleryViewBody extends StatelessWidget {
  const _GalleryViewBody();

  // A dropdown menu for additional selection tools.
  Widget _buildSelectionTitle(BuildContext context, int selected) {
    final vm = context.watch<GalleryViewModel>();

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

  // A dropdown menu for active group.
  Widget _buildGroupTitle(BuildContext context) {
    final vm = context.watch<GalleryViewModel>();
    final selectedLabel = vm.selectedGroup?.name ?? 'Select group';

    return PopupMenuButton<String>(
      tooltip: 'Active group',
      onSelected: (groupId) async => vm.selectGroup(groupId),
      itemBuilder:
          (context) =>
              vm.availableGroups.map((group) {
                return PopupMenuItem<String>(
                  value: group.id,
                  child: Text(group.name),
                );
              }).toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(selectedLabel),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  // The selection bar is only visible while in selection mode.
  AppBar _buildSelectionBar(BuildContext context) {
    final vm = context.watch<GalleryViewModel>();
    final count = vm.selectedItems.length;
    return AppBar(
      centerTitle: false,
      title: _buildSelectionTitle(context, count),
      actions: [
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
    final vm = context.watch<GalleryViewModel>();
    return AppBar(
      centerTitle: false,
      title: _buildGroupTitle(context),
      actions: [
        PhotoViewModeToggle(
          value: vm.groupByDate,
          onChanged: (value) => vm.setGroupByDate(value),
        ),
        const SizedBox(width: 8),
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
        if (item.isMine)
          Positioned(
            top: 4,
            left: 4,
            child: Icon(Icons.person, color: iconColor),
          ),
        //if (item.isUploaded) Positioned(top: 4,right: 4, child: Icon(Icons.cloud_done, color: iconColor)),
      ],
    );
  }

  void _onItemTap(BuildContext context, PhotoItem item) {
    final vm = context.read<GalleryViewModel>();
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

  /// To show all photos in a plain gridview, chronologically sorted.
  ScrollView _buildPlainGridView(BuildContext context) {
    final vm = context.watch<GalleryViewModel>();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: vm.items.length,
      itemBuilder: (context, index) {
        final item = vm.items[index];
        return GestureDetector(
          onTap: () => _onItemTap(context, item),
          onLongPress: () {
            vm.enterSelectionMode();
            vm.toggleSelected(item);
          },
          child: _buildItem(context, item, vm.isSelected(item)),
        );
      },
    );
  }

  /// To show all photos sectionized by date intervals, to make browsing easier.
  ScrollView _buildSectionizedView(BuildContext context) {
    // Create a list of collapsible sections that contain grid views.
    // One section for each date interval.
    final vm = context.watch<GalleryViewModel>();
    final sections = GalleryViewModel.groupPhotosByDate(vm.items);
    return ListView(
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
    );
  }

  /// Show different content depending on the state of the view model.
  Widget _buildContent(BuildContext context) {
    final vm = context.watch<GalleryViewModel>();

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.availableGroups.isEmpty) {
      return const Center(child: Text('You are not a member of any group.'));
    }

    if (vm.items.isEmpty) {
      return const Center(
        child: Text('No photos found for the selected group.'),
      );
    }

    return vm.groupByDate
        ? _buildSectionizedView(context)
        : _buildPlainGridView(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GalleryViewModel>();

    return Scaffold(
      appBar:
          vm.isSelectionMode
              ? _buildSelectionBar(context)
              : _buildNormalBar(context),
      body: _buildContent(context),
    );
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
