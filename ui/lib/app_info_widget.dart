import 'package:flutter/material.dart';
import 'package:letso/licenses_widget.dart';

class AppInfoWidget extends StatelessWidget {
  final String apiVersion;
  final String serverVersion;
  final String appVersion;
  const AppInfoWidget({
    super.key,
    required this.apiVersion,
    required this.serverVersion,
    required this.appVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Information"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("API: $apiVersion", textAlign: TextAlign.center),
              ),
              Expanded(
                child: Text(
                  "Server: $serverVersion",
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text("App: $appVersion", textAlign: TextAlign.center),
              ),
            ],
          ),
          Divider(),
          Text(
            'Licenses',
            style: Theme.of(
              context,
            ).textTheme.titleMedium, // Or headlineLarge, titleLarge, etc.
          ),
          Divider(),
          Expanded(child: LicencesWidget()),
        ],
      ),
    );
  }
}
