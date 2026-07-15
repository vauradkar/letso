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
  late Future<Either<String, Directory>> _browseFuture;
  late void Function() _appStateListener;

  @override
  void initState() {
    super.initState();
    _browseFuture = widget.appState.api.browsePath(currentDirectory);
    _appStateListener = () {
      setState(() {});
    };
    widget.appState.registerListener(_appStateListener);
  }

  @override
  void dispose() {
    widget.appState.unregisterListener(_appStateListener);
    super.dispose();
  }

  void _navigateTo(PortablePath newDirectory) {
    setState(() {
      currentDirectory = newDirectory;
      _browseFuture = widget.appState.api.browsePath(currentDirectory);
    });
  }

  /// Exposed for testing only. Drives navigation the same way a directory
  /// tap would, without depending on widget hit-testing.
  @visibleForTesting
  void navigateToForTesting(PortablePath path) => _navigateTo(path);

  void _onItemTap(DirectoryEntry item) {
    logger.d('Item tapped: ${item.name}');
    if (item.isDirectory) {
      _navigateTo(currentDirectory.add(item.name));
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

    logger.d('Current directory updated: ${currentDirectory.subPath(index)}');
    _navigateTo(currentDirectory.subPath(index));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<String, Directory>>(
      future: _browseFuture,
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
          var directory = snapshot.data!.orNull()!;
          // TODO: the server modifies the currentDirectory relative to root
          //       Fix this on server side.
          if (currentDirectory.getAncestor(0) == "/" &&
              directory.currentPath.getAncestor(0) != "/") {
            var cp = const PortablePath(["/"]);
            for (int i = 0; i < directory.currentPath.length; i++) {
              cp = cp.add(directory.currentPath.getAncestor(i)!);
            }
            directory = Directory(currentPath: cp, items: directory.items);
          }
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
