import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:letso/api.dart';
import 'package:letso/app_info_widget.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/app_state.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/log_viewer.dart';
import 'package:letso/settings.dart';
import 'package:letso/settings_page.dart';
import 'package:letso/status_bar.dart';
import 'package:letso/upload_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Signature for the function that loads [AppState] from the network/storage.
typedef AppStateLoader = Future<AppState> Function();

/// The default production loader — builds [AppState] from live network calls.
Future<AppState> _defaultLoadAppState() async {
  final settings = await Settings.loadSettings();
  final Api api = Api.create(settings);
  final serverVersion = await api.getServerVersion();
  final apiVersion = await api.getApiVersion();
  final packageInfo = await PackageInfo.fromPlatform();
  return AppState(
    settings: settings,
    api: api,
    uploadManager: UploadManager(api: api),
    serverVersion: serverVersion,
    apiVersion: apiVersion,
    packageInfo: packageInfo,
  );
}

// This is the main entry point for the Flutter application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // logger.i("Application started");
  await logger.initLogger(logSize: 10000);
  logger.i("Logger initialized");

  runApp(
    MaterialApp(
      title: 'letso',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: MyApp(),
    ),
  );
}

// Define the main application widget.
class MyApp extends StatefulWidget {
  /// Override the loader in tests to avoid real network calls.
  final AppStateLoader loader;

  const MyApp({super.key, this.loader = _defaultLoadAppState});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Resolved AppState — null until the first future completes.
  AppState? appState;
  late Future<AppState> _appStateFuture;

  @override
  void initState() {
    super.initState();
    _appStateFuture = widget.loader();
  }

  /// Creates a fresh future (e.g. after settings change). This is the only
  /// legitimate place to call the loader after [initState].
  void _reloadAppState() {
    setState(() {
      _appStateFuture = widget.loader();
    });
  }

  void showSettingsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onChange: _reloadAppState,
          appState: appState,
        ),
      ),
    );
  }

  void showLogsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogViewer(
          logMessages: logger.getLogs(),
          onClear: () {
            logger.clear();
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AsyncSnapshot<AppState> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Column(
          children: [Text("loading preferences"), CircularProgressIndicator()],
        ),
      );
    } else if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    } else if (snapshot.hasData) {
      // Cache the resolved AppState so showSettingsPage can use it
      // synchronously (before the next build).
      appState = snapshot.data as AppState;
      if (appState!.settings.isConfigured()) {
        return Column(
          children: [
            Expanded(child: BrowserContainer(appState: appState!)),
            StatusBar(appState: appState!),
          ],
        );
      } else {
        return Scaffold(
          body: SettingsPage(
            onChange: _reloadAppState,
            appState: appState,
          ),
        );
      }
    } else {
      return const Center(child: Text('No preferences found'));
    }
  }

  /// Exposed for testing only. Triggers a reload of [AppState] by calling
  /// the injected [loader] and rebuilding the widget tree.
  ///
  /// In production code prefer the private [_reloadAppState] which is invoked
  /// through [SettingsPage.onChange].
  @visibleForTesting
  void reloadAppStateForTesting() => _reloadAppState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Let That Sync Out'),
        actions: [
          IconButton(
            onPressed: () => showLogsPage(context),
            icon: Icon(Icons.terminal),
          ),
          IconButton(
            onPressed: () => showSettingsPage(context),
            icon: Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FutureBuilder(
                    future: _appStateFuture,
                    builder: _buildAppInfoWidget,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: FutureBuilder(future: _appStateFuture, builder: _buildMainContent),
    );
  }

  Widget _buildAppInfoWidget(
    BuildContext context,
    AsyncSnapshot<AppState> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      logger.e('Error loading app state: ${snapshot.error}');
      return Center(child: Text('Error: ${snapshot.error}'));
    } else if (snapshot.hasData) {
      AppState appState = snapshot.data as AppState;
      return AppInfoWidget(
        apiVersion: appState.apiVersion,
        serverVersion: appState.serverVersion,
        appVersion: appState.packageInfo.version,
      );
    } else {
      return const Center(child: Text('No data'));
    }
  }
}
