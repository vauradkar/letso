import 'package:flutter/material.dart';
import 'package:letso/app_state.dart';
import 'package:letso/utils.dart';

/// Beautiful StatusBar widget that displays item counts and upload progress
class StatusBar extends StatefulWidget {
  final Color? backgroundColor;
  final Color? textColor;
  final Color? progressColor;
  final double height;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final AppState appState;

  const StatusBar({
    super.key,
    required this.appState,
    this.backgroundColor,
    this.textColor,
    this.progressColor,
    this.height = 56.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.borderRadius,
    this.boxShadow,
  });

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  _StatusBarState();

  @override
  void dispose() {
    widget.appState.unregisterListener(updateListener);
    super.dispose();
  }

  void updateListener() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.appState.registerListener(updateListener);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = widget.backgroundColor ?? colorScheme.surface;
    final txtColor = widget.textColor ?? colorScheme.onSurface;
    final progColor = widget.progressColor ?? colorScheme.primary;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12.0),
        boxShadow:
            widget.boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.appState.isUploading
            ? _buildUploadingStatus(txtColor, progColor)
            : _buildNormalStatus(txtColor),
      ),
    );
  }

  Widget _buildNormalStatus(Color textColor) {
    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          color: textColor.withValues(alpha: 0.7),
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          '${widget.appState.statusInfo.totalItems} items',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Ready',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadingStatus(Color textColor, Color progressColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main status row
        Expanded(
          child: Row(
            children: [
              // Upload icon with animation
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(width: 12),

              // Files info
              if (widget.appState.remainingFiles != null &&
                  widget.appState.totalFiles != null) ...[
                Text(
                  '${widget.appState.totalFiles! - widget.appState.remainingFiles!}/${widget.appState.totalFiles} files',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // Bytes info
              if (widget.appState.remainingBytes != null &&
                  widget.appState.totalBytes != null) ...[
                Text(
                  '${formatBytes(widget.appState.remainingBytes!)}/${formatBytes(widget.appState.totalBytes!)}',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],

              const Spacer(),

              // Progress percentage
              Text(
                '${(widget.appState.bytesProgress * 100).toInt()}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Progress bar
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: widget.appState.bytesProgress,
            backgroundColor: textColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
