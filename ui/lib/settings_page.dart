import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:letso/data.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/settings.dart';
import 'package:letso/synced_directory_setting.dart';

class SettingsPage extends StatefulWidget {
  final Function onChange;
  const SettingsPage({required this.onChange, super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final Settings _settings = Settings();

  // Controllers for the text input fields.
  final TextEditingController _serverAddressController =
      TextEditingController();

  // State variables for managing the UI.
  final List<String> _logOutput = [];
  List<String> currentDirectory = ["."];

  @override
  void initState() {
    super.initState();
    // Load saved settings when the widget is initialized.
  }

  // Asynchronously loads the server address and port from SharedPreferencesAsync.
  Future<void> _loadSettings() async {
    await _settings.load();

    _serverAddressController.text = _settings.serverAddress;
  }

  // Asynchronously saves the server address and port to SharedPreferencesAsync.
  Future<void> _saveSettings() async {
    setState(() {
      _settings.serverAddress = _serverAddressController.text;

      _logOutput.add('Settings saved successfully.');
    });
    _settings.save();
    widget.onChange(); // Notify the parent widget about the change.
  }

  Widget buildServerSettings(
    BuildContext context,
    AsyncSnapshot<void> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator(); // Show loading indicator
    } else if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_buildSettingsForm()],
        ),
      );
    }
  }

  Future<void> _updateSyncPath(SyncPath path, String action) async {
    if (action == 'delete') {
      setState(() async {
        await _settings.removeSyncPath(path);
      });
    } else if (action == 'sync') {
      setState(() async {
        logger.d('Sync action triggered for: $path');
      });
      await _settings.save();
    } else if (action == 'add') {
      setState(() async {
        await _settings.addSyncPath(path);
      });
    }
  }

  Widget buildDecoration(String title, Widget child) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(title),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.blue.shade600, Colors.purple.shade600],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.table_view_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> tabs = [];
    if (!kIsWeb) {
      tabs.add(const Tab(icon: Icon(Icons.backup)));
    }
    tabs.add(const Tab(icon: Icon(Icons.sync)));
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Settings'),
          bottom: TabBar(tabs: tabs),
        ),

        body: FutureBuilder<void>(
          future: _loadSettings(),
          builder: (context, snapshot) {
            List<Widget> tabViews = [];

            if (!kIsWeb) {
              tabViews.add(
                buildDecoration(
                  "Server Settings",
                  buildServerSettings(context, snapshot),
                ),
              );
            }
            tabViews.add(
              buildDecoration(
                "Synced Directories",
                SyncedDirectorySetting(
                  dataFuture: _settings.syncPaths,
                  onActionPressed: _updateSyncPath,
                ),
              ),
            );

            return TabBarView(children: tabViews);
          },
        ),
      ),
    );
  }

  // Widget to build the settings input form.
  Widget _buildSettingsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        UrlInputWidget(
          serverAddressController: _serverAddressController,
          onSave: _saveSettings,
        ),
      ],
    );
  }
}

class UrlInputWidget extends StatefulWidget {
  final TextEditingController serverAddressController;
  final VoidCallback onSave;

  const UrlInputWidget({
    super.key,
    required this.serverAddressController,
    required this.onSave,
  });

  @override
  State<UrlInputWidget> createState() => _UrlInputWidgetState();
}

class _UrlInputWidgetState extends State<UrlInputWidget> {
  bool _isValidUrl = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.serverAddressController.addListener(_validateUrl);
  }

  @override
  void dispose() {
    widget.serverAddressController.removeListener(_validateUrl);
    super.dispose();
  }

  void _validateUrl() {
    final text = widget.serverAddressController.text;

    if (text.isEmpty) {
      setState(() {
        _isValidUrl = false;
        _errorText = null;
      });
      return;
    }

    bool isValid = false;

    try {
      final uri = Uri.parse(text);

      // Check if scheme is http or https
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        // Check if host is not empty
        if (uri.host.isNotEmpty) {
          // If port is specified, validate it
          if (uri.hasPort) {
            isValid = uri.port >= 1 && uri.port <= 65535;
          } else {
            isValid = true;
          }
        }
      }
    } catch (e) {
      isValid = false;
    }

    setState(() {
      _isValidUrl = isValid;
      _errorText = isValid ? null : 'Please enter a valid URL';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.serverAddressController,
          decoration: InputDecoration(
            labelText: 'Server Address',
            hintText: 'https://example.com:port',
            errorText: _errorText,
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isValidUrl ? widget.onSave : null,
          child: Text('Save'),
        ),
      ],
    );
  }
}
