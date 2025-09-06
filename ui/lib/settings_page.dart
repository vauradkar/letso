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
  final TextEditingController _serverPortController = TextEditingController();

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
    _serverPortController.text = _settings.serverPort;
  }

  // Asynchronously saves the server address and port to SharedPreferencesAsync.
  Future<void> _saveSettings() async {
    setState(() {
      _settings.serverAddress = _serverAddressController.text;
      _settings.serverPort = _serverPortController.text;

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
          children: [
            _buildSettingsForm(),
            const SizedBox(height: 20),
            const Text(
              'Log Output:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            // Display the log messages.
            ..._logOutput.map(
              (log) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(log),
              ),
            ),
          ],
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

  Widget buildDecoration(Widget child) {
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
            _buildHeader(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            'Data Management',
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Settings'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.backup)),
              Tab(icon: Icon(Icons.sync)),
            ],
          ),
        ),

        body: FutureBuilder<void>(
          future: _loadSettings(),
          builder: (context, snapshot) {
            return TabBarView(
              children: [
                buildDecoration(buildServerSettings(context, snapshot)),
                buildDecoration(
                  SyncedDirectorySetting(
                    dataFuture: _settings.syncPaths,
                    onActionPressed: _updateSyncPath,
                  ),
                ),
              ],
            );
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
        const Text(
          'Please enter server details:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _serverAddressController,
          decoration: const InputDecoration(
            labelText: 'Server Address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _serverPortController,
          decoration: const InputDecoration(
            labelText: 'Server Port',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saveSettings,
          child: const Text('Save Settings'),
        ),
      ],
    );
  }
}
