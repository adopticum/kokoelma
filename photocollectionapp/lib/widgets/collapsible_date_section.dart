import 'package:flutter/material.dart';

class CollapsibleDateSection<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final bool isSelectionMode;
  final Set<T> selectedItems;
  final bool isUploading;
  final bool showSelectionActions;
  final bool initiallyExpanded;
  final String itemLabelSingular;
  final String itemLabelPlural;
  final Widget Function(BuildContext context, T item, bool isSelected) itemBuilder;
  final ValueChanged<T>? onItemTap;
  final ValueChanged<T>? onItemLongPress;
  final ValueChanged<T>? onToggleSelection;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final EdgeInsetsGeometry? headerPadding;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;
  final int crossAxisCount;

  const CollapsibleDateSection({
    super.key,
    required this.title,
    required this.items,
    required this.isSelectionMode,
    required this.selectedItems,
    required this.isUploading,
    required this.itemBuilder,
    this.showSelectionActions = true,
    this.initiallyExpanded = true,
    this.itemLabelSingular = 'item',
    this.itemLabelPlural = 'items',
    this.onItemTap,
    this.onItemLongPress,
    this.onToggleSelection,
    this.onSelectAll,
    this.onDeselectAll,
    this.headerPadding,
    this.contentPadding,
    this.backgroundColor,
    this.borderRadius,
    this.crossAxisCount = 3,
  });

  @override
  State<CollapsibleDateSection<T>> createState() => _CollapsibleDateSectionState<T>();
}

class _CollapsibleDateSectionState<T> extends State<CollapsibleDateSection<T>> {
  late bool _expanded;

  String get _itemCountText {
    final countText =
        widget.items.length == 1
            ? '1 ${widget.itemLabelSingular}'
            : '${widget.items.length} ${widget.itemLabelPlural}';

    if (!widget.isSelectionMode) {
      return countText;
    }

    final selectionCountInSection = widget.items.where((item) {
      return widget.selectedItems.contains(item);
    }).length;

    return 'Selected $selectionCountInSection of $countText';
  }

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor =
        widget.backgroundColor ?? colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius:
                  widget.borderRadius != null
                      ? (widget.borderRadius as BorderRadius)
                      : BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: widget.headerPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: theme.textTheme.titleMedium),
                          Text(
                            _itemCountText,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (widget.showSelectionActions && widget.isSelectionMode) ...[
                      IconButton(
                        tooltip: 'Deselect all in this section',
                        onPressed: widget.onDeselectAll,
                        icon: const Icon(Icons.close),
                      ),
                      IconButton(
                        tooltip: 'Select all in this section',
                        onPressed: widget.onSelectAll,
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: widget.contentPadding ?? const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.crossAxisCount,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = widget.selectedItems.contains(item);

                    return GestureDetector(
                      onTap: () {
                        if (widget.isSelectionMode && widget.onToggleSelection != null) {
                          widget.onToggleSelection!(item);
                        } else if (widget.onItemTap != null) {
                          widget.onItemTap!(item);
                        }
                      },
                      onLongPress: () {
                        if (widget.isUploading) return;
                        if (widget.onItemLongPress != null) {
                          widget.onItemLongPress!(item);
                        } else if (widget.isSelectionMode && widget.onToggleSelection != null) {
                          widget.onToggleSelection!(item);
                        }
                      },
                      child: widget.itemBuilder(context, item, isSelected),
                    );
                  },
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }
}
