import 'package:flutter/material.dart';
import 'oss_licenses.dart';

class LicencesWidget extends StatelessWidget {
  const LicencesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: ossLicenses.length,
      itemBuilder: (_, index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LicenceDetailWidget(
                      title:
                          ossLicenses[index].name[0].toUpperCase() +
                          ossLicenses[index].name.substring(1),
                      licence: ossLicenses[index].license!,
                    ),
                  ),
                );
              },
              //capitalize the first letter of the string
              title: Text(
                ossLicenses[index].name[0].toUpperCase() +
                    ossLicenses[index].name.substring(1),
                style: const TextStyle(fontFamily: "FiraMonoNerdFont"),
              ),
              subtitle: Text(ossLicenses[index].description),
            ),
          ),
        );
      },
    );
  }
}

//detail page for the licence
class LicenceDetailWidget extends StatelessWidget {
  final String title, licence;
  const LicenceDetailWidget({
    super.key,
    required this.title,
    required this.licence,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [Text(licence, style: const TextStyle(fontSize: 15))],
            ),
          ),
        ),
      ),
    );
  }
}
