import 'package:flutter/material.dart';

class PhotoViewModeToggle extends StatelessWidget {
  const PhotoViewModeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {

    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: true,
          //label: Text(''),
          icon: Icon(Icons.calendar_month, size: 18),
        ),
        ButtonSegment<bool>(
          value: false,
          //label: Text(''),
          icon: Icon(Icons.grid_view, size: 18),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        onChanged(selection.first);
      },
      multiSelectionEnabled: false,
      showSelectedIcon: false,
      /*style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        //padding: const WidgetStatePropertyAll(            EdgeInsets.symmetric(horizontal: 10, vertical: 2),          ),
        minimumSize: const WidgetStatePropertyAll(Size(72, 30)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),*/
    );
    
    /*
    return Container(
      //height: 36,
      //margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: true,
            //label: Text(''),
            icon: Icon(Icons.calendar_month, size: 18),
          ),
          ButtonSegment<bool>(
            value: false,
            //label: Text(''),
            icon: Icon(Icons.grid_view, size: 18),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) {
          onChanged(selection.first);
        },
        multiSelectionEnabled: false,
        showSelectedIcon: false,
        /*style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          //padding: const WidgetStatePropertyAll(            EdgeInsets.symmetric(horizontal: 10, vertical: 2),          ),
          minimumSize: const WidgetStatePropertyAll(Size(72, 30)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
        ),*/
      ),
    );
    */
  }
}
