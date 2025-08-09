import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final Function onChange;
  const SettingsPage({required this.onChange, super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  // Controllers for the text input fields.
  final TextEditingController _serverAddressController =
      TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();

  // State variables for managing the UI.
  String? _serverAddress;
  String? _serverPort;
  final List<String> _logOutput = [];
  List<String> currentDirectory = ["."];

  @override
  void initState() {
    super.initState();
    // Load saved settings when the widget is initialized.
  }

  // Asynchronously loads the server address and port from SharedPreferencesAsync.
  Future<void> _loadSettings() async {
    final prefs = SharedPreferencesAsync();
    String? serverAddress = await prefs.getString('serverAddress');
    String? serverPort = await prefs.getString('serverPort');
    _serverAddress = serverAddress;
    _serverPort = serverPort;
    _serverAddressController.text = _serverAddress ?? '';
    _serverPortController.text = _serverPort ?? '';
  }

  // Asynchronously saves the server address and port to SharedPreferencesAsync.
  Future<void> _saveSettings() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('serverAddress', _serverAddressController.text);
    await prefs.setString('serverPort', _serverPortController.text);
    setState(() {
      _serverAddress = _serverAddressController.text;
      _serverPort = _serverPortController.text;
      _logOutput.add('Settings saved successfully.');
    });
    widget.onChange(); // Notify the parent widget about the change.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Second Screen')),
      body: FutureBuilder<void>(
        future: _loadSettings(),
        builder: (context, snapshot) {
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
        },
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
