import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:letso/app_state.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/data.dart';
import 'package:letso/settings.dart';
import 'package:letso/utils.dart';

enum ViewType { icon, list }

enum SortColumn { name, size, kind, mtime }

enum SortOrder { ascending, descending }

class FileBrowser extends StatefulWidget {
  final Directory directory;
  final EventHandlers eventHandlers;
  final AppState appState;

  const FileBrowser({
    super.key,
    required this.directory,
    required this.eventHandlers,
    required this.appState,
  });

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

String formatTime(String mtime) {
  try {
    DateTime dt = DateTime.parse(mtime).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // Date only
    final yesterday = DateTime(now.year, now.month, now.day - 1); // Date only
    final inputDate = DateTime(dt.year, dt.month, dt.day); // Date only of input

    if (inputDate == today) {
      return DateFormat('HH:mm').format(dt);
    } else if (inputDate == yesterday) {
      return 'Yesterday at ${DateFormat('HH:mm').format(dt)}';
    } else {
      // For other dates, format as desired, e.g., "Mon, Oct 2, 2025 at 09:05 PM"
      return DateFormat('yyyy-mm-dd - HH:mm').format(dt);
    }
  } catch (e) {
    return mtime;
  }
}

class _FileBrowserState extends State<FileBrowser> {
  ViewType _viewType = ViewType.list;
  SortColumn _sortColumn = SortColumn.name;
  SortOrder _sortOrder = SortOrder.ascending;
  List<DirectoryEntry> _sortedItems = [];

  @override
  void initState() {
    super.initState();
    _sortedItems = List.from(widget.directory.items);
    _sortItems();
  }

  @override
  void didUpdateWidget(FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory.items != widget.directory.items) {
      _sortedItems = List.from(widget.directory.items);
      _sortItems();
    }
  }

  void _sortItems() {
    _sortedItems.sort((a, b) {
      int comparison = 0;

      // Always put directories first
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      switch (_sortColumn) {
        case SortColumn.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortColumn.size:
          comparison = a.size.compareTo(b.size);
          break;
        case SortColumn.kind:
          String aKind = a.isDirectory
              ? 'Directory'
              : _getFileExtension(a.name);
          String bKind = b.isDirectory
              ? 'Directory'
              : _getFileExtension(b.name);
          comparison = aKind.compareTo(bKind);
          break;
        case SortColumn.mtime:
          comparison = a.mtime.compareTo(b.mtime);
          break;
      }

      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }

  String _getFileExtension(String fileName) {
    int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'File';
    }
    return fileName.substring(dotIndex + 1).toUpperCase();
  }

  void _onColumnHeaderTap(SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortOrder = _sortOrder == SortOrder.ascending
            ? SortOrder.descending
            : SortOrder.ascending;
      } else {
        _sortColumn = column;
        _sortOrder = SortOrder.ascending;
      }
      _sortItems();
    });
  }

  Widget _buildColumnHeader(String title, SortColumn column) {
    bool isActive = _sortColumn == column;

    return InkWell(
      onTap: () => _onColumnHeaderTap(column),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Theme.of(context).primaryColor : null,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              Icon(
                _sortOrder == SortOrder.ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildDirectoryPathButtons(context);
  }

  Widget _buildButton(Widget icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        _buildButton(
          Transform.rotate(
            angle: -pi / 2,
            child: Icon(Icons.subdirectory_arrow_right),
          ),
          "Up",
          () {
            widget.eventHandlers.onAncestorTap(
              widget.directory.currentPath.length - 2,
            );
          },
        ),
        _buildButton(Icon(Icons.upload_file), "File", () {
          widget.appState.uploadManager.pickAndUploadFiles(
            widget.directory.currentPath,
          );
        }),
        if (!kIsWeb)
          _buildButton(Icon(Icons.drive_folder_upload), "Directory", () {
            widget.appState.uploadManager.uploadDirectory(
              widget.directory.currentPath,
            );
          }),
        if (!kIsWeb)
          _buildButton(Icon(Icons.sync), "Sync", () async {
            var (syncPath, result) = await widget.appState.uploadManager
                .selectAndSyncDirectory(widget.directory.currentPath);
            var res = await result;
            res.logAll();
            if (syncPath != null) {
              var settings = Settings();
              await settings.load();
              settings.addSyncPath(syncPath);
            }
          }),
        const Spacer(),
        ToggleButtons(
          borderRadius: BorderRadius.circular(4),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
          isSelected: [_viewType == ViewType.icon, _viewType == ViewType.list],
          onPressed: (int index) {
            setState(() {
              _viewType = index == 0 ? ViewType.icon : ViewType.list;
            });
          },
          children: const [
            Icon(Icons.grid_view, size: 20),
            Icon(Icons.list, size: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: child,
    );
  }

  Widget _buildDirectoryPathButtons(BuildContext context) {
    List<Widget> ancestors = [];
    for (int i = 0; i < widget.directory.currentPath.length; i++) {
      String ancestor = widget.directory.currentPath.getAncestor(i)!;
      ancestors.add(
        ElevatedButton(
          onPressed: () {
            widget.eventHandlers.onAncestorTap(i);
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: const TextStyle(fontFamily: "FiraMonoNerdFont"),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero, // Makes the button square
            ),
          ),
          child: Text(ancestor),
        ),
      );
    }
    return Column(
      children: [
        _buildContainer(Row(children: ancestors)),
        // Toolbar
        _buildContainer(_buildButtons()),
        // Content
        Expanded(
          child: _viewType == ViewType.icon
              ? _buildIconView()
              : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildIconView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: _sortedItems.length,
      itemBuilder: (context, index) {
        final item = _sortedItems[index];
        return InkWell(
          onTap: () => widget.eventHandlers.onItemTap(item),
          onDoubleTap: () => widget.eventHandlers.onItemDoubleTap(item),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  size: 48,
                  color: item.isDirectory ? Colors.blue[600] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildColumnHeader('Name', SortColumn.name),
              ),
              Expanded(
                flex: 1,
                child: _buildColumnHeader('Size', SortColumn.size),
              ),
              Expanded(
                flex: 1,
                child: _buildColumnHeader('Kind', SortColumn.kind),
              ),
              Expanded(
                flex: 2,
                child: _buildColumnHeader('Modified', SortColumn.mtime),
              ),
            ],
          ),
        ),
        // List items
        Expanded(
          child: ListView.builder(
            itemCount: _sortedItems.length,
            itemBuilder: (context, index) {
              final item = _sortedItems[index];
              return InkWell(
                onTap: () => widget.eventHandlers.onItemTap(item),
                onDoubleTap: () => widget.eventHandlers.onItemDoubleTap(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(children: buildRow(item)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> buildRow(DirectoryEntry item) {
    return [
      Expanded(
        flex: 3,
        child: Row(
          children: [
            Icon(
              item.isDirectory ? Icons.folder : Icons.insert_drive_file,
              size: 20,
              color: item.isDirectory ? Colors.blue[600] : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        flex: 1,
        child: Text(
          item.isDirectory ? '--' : formatBytes(item.size),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      Expanded(
        flex: 1,
        child: Text(
          item.isDirectory ? 'Dir' : _getFileExtension(item.name),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      Expanded(
        flex: 2,
        child: Text(
          formatTime(item.mtime),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ];
  }
}
