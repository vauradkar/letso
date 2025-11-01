import 'package:dart_either/dart_either.dart';
import 'package:flutter/material.dart';
import 'package:letso/app_state.dart';
import 'package:letso/data.dart';
import 'package:letso/file_browser.dart';
import 'package:letso/logger_manager.dart';

class EventHandlers {
  final Function(DirectoryEntry) onItemTap;
  final Function(DirectoryEntry) onItemDoubleTap;
  final Function(int) onAncestorTap;

  EventHandlers({
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onAncestorTap,
  });
}

class BrowserContainer extends StatefulWidget {
  final AppState appState;
  const BrowserContainer({super.key, required this.appState});

  @override
  State<BrowserContainer> createState() => _BrowserContainerState();
}

class _BrowserContainerState extends State<BrowserContainer> {
  PortablePath currentDirectory = PortablePath(["/"]);

  @override
  void initState() {
    super.initState();
    widget.appState.registerListener(() {
      setState(() {});
    });
  }

  void _onItemTap(DirectoryEntry item) {
    logger.d('Item tapped: ${item.name}');
    if (item.isDirectory) {
      setState(() {
        currentDirectory.add(item.name);
      });
    } else {
      logger.d('Tapped on file: ${item.name}');
    }
  }

  void _onItemDoubleTap(DirectoryEntry item) {
    logger.d('Item double tapped: ${item.name}');
    _onItemTap(item);
  }

  void _onAncestorTap(int index) {
    logger.d('Ancestor tapped at index: $index');
    if (index < 0) {
      return;
    }
    if (index > currentDirectory.length - 1) {
      // If the last item is tapped, do nothing.
      return;
    }

    setState(() {
      currentDirectory = currentDirectory.subPath(index);
      logger.d('Current directory updated: $currentDirectory');
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<String, Directory>>(
      future: widget.appState.api.browsePath(currentDirectory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          if (snapshot.data!.isLeft) {
            return Center(child: Text('Error: ${snapshot.data!.left}'));
          }
          EventHandlers eventHandlers = EventHandlers(
            onItemTap: _onItemTap,
            onItemDoubleTap: _onItemDoubleTap,
            onAncestorTap: _onAncestorTap,
          );
          final directory = snapshot.data!.orNull()!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.appState.updateItemsCount(directory.items.length);
          });
          return FileBrowser(
            directory: directory,
            eventHandlers: eventHandlers,
            appState: widget.appState,
          );
        } else {
          // Handle case where data is null
          return const Center(child: Text('No data available'));
        }
      },
    );
  }
}
