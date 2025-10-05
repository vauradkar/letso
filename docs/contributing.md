# Contributing

Thank you for considering contributing to this project!

## How to Contribute

Let us know about bugs or feature requests by opening an issue. To submit code changes, please open a pull request and ensure your code passes all tests.

## Building container

You can build the container from root of project directory with

```shell
docker build --progress=plain --no-cache -t letso:latest -f container/Dockerfile .
```

## Generating licences information for new dependecies

Run the following command which will generate `lib/oss_licenses.dart` and commit that file.

```shell
flutter pub run flutter_oss_licenses:generate.dart
```
