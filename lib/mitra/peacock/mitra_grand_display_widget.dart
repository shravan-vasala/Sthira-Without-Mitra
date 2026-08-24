import 'package:flutter/material.dart';
import 'mitra_peacock_manifest.dart';
import 'mitra_grand_display_controller.dart';

class MitraGrandDisplayWidget extends StatefulWidget {
  final MitraGrandDisplayController controller;
  final bool showDebugOverlay;
  final double scale;

  const MitraGrandDisplayWidget({
    super.key,
    required this.controller,
    this.showDebugOverlay = false,
    this.scale = 1.0,
  });

  @override
  State<MitraGrandDisplayWidget> createState() => _MitraGrandDisplayWidgetState();
}

class _MitraGrandDisplayWidgetState extends State<MitraGrandDisplayWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(MitraGrandDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.controller.currentFrame;

    // The image itself, sized explicitly to the canvas dimensions and scaled
    Widget imageContent = SizedBox(
      width: MitraPeacockManifest.canvasWidth * widget.scale,
      height: MitraPeacockManifest.canvasHeight * widget.scale,
      child: Image.asset(
        frame.asset,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );

    // Apply the debug overlay if requested
    if (widget.showDebugOverlay) {
      imageContent = Stack(
        clipBehavior: Clip.none,
        children: [
          imageContent,
          // Logical Pivot Crosshair
          Positioned(
            left: MitraPeacockManifest.pivotX * widget.scale - 10,
            top: MitraPeacockManifest.pivotY * widget.scale - 10,
            child: const Icon(Icons.add, color: Colors.red, size: 20),
          ),
          // Ground Line
          Positioned(
            left: 0,
            top: MitraPeacockManifest.pivotY * widget.scale,
            child: Container(
              width: MitraPeacockManifest.canvasWidth * widget.scale,
              height: 1,
              color: Colors.red.withOpacity(0.5),
            ),
          ),
          // State Info
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black87,
              child: Text(
                'STATE: ${widget.controller.currentState.name.toUpperCase()}\nACTION: ${frame.id}\nDURATION: ${frame.duration.inMilliseconds}ms',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      );
    }

    // Use Align with FractionalOffset to pin the pivot exactly to the center of the available space.
    // By using FractionalOffset, the point (pivotX/canvasWidth, pivotY/canvasHeight) of the image
    // is locked to the exact same fractional point of the parent container.
    return SizedBox.expand(
      child: Align(
        alignment: MitraPeacockManifest.fractionalOffset,
        child: imageContent,
      ),
    );
  }
}
