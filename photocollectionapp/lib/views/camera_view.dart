import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import '../viewmodels/camera_viewmodel.dart';

// Camera UX issues:
//FIXED: Photo must save to correct folder (photo roll).
//FIXED: Main camera starts mirrore, until change of focal length etc.
//FIXED: Remove color grading style option.
//FIXED: We have lost the option to switch focal lenghts.
//OK: Aspect ratio appears to do nothing. Only affects save.
//OK: Camera does auto focus.
//OK: Tap handler works.
//FIXED: Screen flash animation for visual feedback that photo was taken.
//TODO: Camera does not focus on tap, even though it should do by default.

class CameraView extends StatefulWidget {
  final VoidCallback onMenuPressed;
  const CameraView({super.key, required this.onMenuPressed});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with SingleTickerProviderStateMixin {
  late final AnimationController _screenFlashController;

  @override
  void initState() {
    super.initState();

    _screenFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CameraViewModel>().startLocationTracking();
    });
  }

  @override
  void dispose() {
    _screenFlashController.dispose();
    super.dispose();
  }

  void _triggerScreenFlashAnimation() {
    // Ignore if already animating
    if (_screenFlashController.isAnimating) return;
    _screenFlashController.forward(from: 0);
  }

  // Default values for sensor position, aspect, zoom etc.
  final SensorConfig _sensorConfig = SensorConfig.single(
    sensor: Sensor.position(SensorPosition.back),
    aspectRatio: CameraAspectRatios.ratio_4_3, //CameraAspectRatios.ratio_1_1,
    zoom: 0.0,
    flashMode: FlashMode.auto,
  );

  Widget _buildCamerAwesome() {
    final vm = context.read<CameraViewModel>();

    return CameraAwesomeBuilder.awesome(
      // How and where we save photos
      saveConfig: vm.createSaveConfig(),
      // Default values for sensor position, aspect, zoom etc.
      sensorConfig: _sensorConfig,
      // Prevent use of "photo live filters", which distorts colors.
      defaultFilter: AwesomeFilter.None,
      availableFilters: [],
      // Set how the preview is drawn
      previewFit: CameraPreviewFit.contain,
      //previewPadding: const EdgeInsets.only(left: 150, top: 100),
      //previewAlignment: Alignment.topRight,

      // Event handler for when photo is taken (fires twice).
      onMediaCaptureEvent: (event) {
        if (event.isPicture && event.status == MediaCaptureStatus.success) {
          final pendingPaths = vm.consumePendingPhotoPaths();
          for (final path in pendingPaths) {
            vm.enqueueCapturedPhoto(path);
          }
          vm.notifyPhotoCaptured();
          _triggerScreenFlashAnimation();
        }
      },


      // Buttons of CamerAwesome UI will use this theme
      /*
        theme: AwesomeTheme(
          bottomActionsBackgroundColor: Colors.cyan.withValues(alpha: 0.5),
          buttonTheme: AwesomeButtonTheme(
            backgroundColor: Colors.cyan.withValues(alpha: 0.5),
            iconSize: 20,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            // Tap visual feedback (ripple, bounce...)
            buttonBuilder: (child, onTap) {
              return ClipOval(
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    splashColor: Colors.cyan,
                    highlightColor: Colors.cyan.withValues(alpha: 0.5),
                    onTap: onTap,
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
        */

      // Handle gestures on the preview, such as tap to focus or scale to zoom
      onPreviewTapBuilder:
          (state) => OnPreviewTap(
            onTap: (position, flutterPreviewSize, pixelPreviewSize) {
              // Handle tap to focus (default) or take a photo for instance
              // ...
            },
            onTapPainter: (position) {
              final int radius = 50;
              // Tap feedback, here we just show a circle
              return Positioned(
                left: position.dx - radius,
                top: position.dy - radius,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    width: (2 * radius).toDouble(),
                    height: (2 * radius).toDouble(),
                  ),
                ),
              );
            },
            // Duration during which the feedback should be shown
            tapPainterDuration: const Duration(seconds: 2),
          ),

      // Top widgets
      topActionsBuilder:
          (state) => AwesomeTopActions(
            //padding: EdgeInsets.zero,
            state: state,
            children:
                state is PhotoCameraState
                    ? [
                      Expanded(child: AwesomeFlashButton(state: state)),
                      Expanded(child: AwesomeAspectRatioButton(state: state)),
                    ]
                    : [
                      // not in PhotoCameraState, should not happen
                    ],
          ),

      // Custom middle widgets
      /*
        middleContentBuilder: (state) {
          return Column(
            children: [
              /*
              const Spacer(),
              Builder(builder: (context) {
                return Container(
                  color: AwesomeThemeProvider.of(context)
                      .theme
                      .bottomActionsBackgroundColor,
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 10, top: 10),
                      child: Text(
                        "Take your best shot!",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              */
            ],
          );
        },
        */

      // Custom bottom widgets with focal length selector.
      bottomActionsBuilder:
          (state) => Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Focal length row
              if (state is PhotoCameraState)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AwesomeSensorTypeSelector(state: state),
                ),

              // Main controls
              AwesomeBottomActions(
                state: state,
                //center: AwesomeCaptureButton(state: state),
                left: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                  onPressed: widget.onMenuPressed,
                ),
                right: AwesomeCameraSwitchButton(state: state),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildCamerAwesome(),

          // Overlay on top of CamerAwesome to flash the screen when photo is taken.
          Positioned.fill(
            child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _screenFlashController,
                  builder: (_, _) {
                    // Create a flash curve using sinus.
                    final opacity = sin(_screenFlashController.value * pi);
                    return Container(
                      color: Colors.white.withAlpha((230 * opacity).toInt()),
                    );
                  },
                ),
              ),
          ),
        ],
      ),
    );
  }
}




/*
AwesomeFlashButton(
  // Current CameraState
  state: state,
  // You can provide your own icon builder with a custom icon for each flash mode for example.
  iconBuilder: (flashMode) {
    switch (flashMode) {
      case FlashMode.none:
        return const Icon(Icons.flash_off);
      case FlashMode.on:
        return const Icon(Icons.flash_on);
      case FlashMode.auto:
        return const Icon(Icons.flash_auto);
      case FlashMode.always:
        return const Icon(Icons.flashlight_on);
    }
  },
  // You can provide a custom theme to the button. If you don't, it will use the theme from CameraAwesomeBuilder
  theme: AwesomeTheme(
    buttonTheme: AwesomeButtonTheme(
      iconSize: 28,
      padding: const EdgeInsets.all(8),
      foregroundColor: Colors.black,
      backgroundColor: Colors.white,
    ),
  ),
  onFlashTap: (sensorConfig, flashMode) {
    // You may want to update your custom UI or save the flash mode in the settings of your app for example
    doSomethingCustom();

    // Finally, update the flash mode of the sensor config
    sensorConfig.setFlashMode(flashMode);
  },
)

 */

/*
AwesomeCameraSwitchButton(
  // Current CameraState
  state: state,
  // You can set a scale value for this button to make it look smaller or bigger than the other ones
  scale: 1.5,
  // You can provide a custom theme to the button. If you don't, it will use the theme from CameraAwesomeBuilder
  theme: AwesomeTheme(
    buttonTheme: AwesomeButtonTheme(
      iconSize: 28,
      padding: const EdgeInsets.all(8),
      foregroundColor: Colors.black,
      backgroundColor: Colors.white,
    ),
  ),
  // Change the switch camera behaviour logic
  onSwitchTap: (state) {
    // Aspect ratio is reset by default when switching cameras (it goes back to 4:3).
    // You can change this behaviour by overriding the aspect ratio in the switchCameraSensor method.
    state.switchCameraSensor(
      aspectRatio: state.sensorConfig.aspectRatio,
    );
  },
  // Set the icon you want to display for the switch camera button
  iconBuilder: () {
    return MyCustomIcon();
  },
)

//  By default, the SensorConfig goes back to a SensorConfig with the default values of its constructor:
SensorConfig({
  required this.sensor,
  FlashMode flash = FlashMode.none,
  SensorType type = SensorType.wideAngle,
  this.captureDeviceId,
  CameraAspectRatios aspectRatio = CameraAspectRatios.ratio_4_3,
  double currentZoom = 0.0,
})

 */


/*
// capture button
AwesomeCaptureButton(state: state)

 */
