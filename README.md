# Letso

Letso is a project designed to sync files and directories from desktop/laptop or mobile to a remote server.

## Installation

### Using Docker

1. Ensure you have Docker installed on your system. If not, you can download it from [Docker's official website](https://www.docker.com/).

1. Get the default .env and docker-compose files

    ```shell
    mkdir ./letso
    cd ./letso
    wget -O docker-compose.yml https://github.com/vauradkar/letso/releases/latest/download/docker-compose.yml
    wget -O .env https://github.com/vauradkar/letso/releases/latest/download/example.env
    ```

1. Populate the .env file with custom values

    Default env file looks like below

   ```bash
   # The location where your uploaded files are stored
   PLOAD_LOCATION=./library

   # The Letso version to use. You can pin this to a specific version like "v0.0.1"
   LETSO_VERSION=release
   
   # To debug, set it to DEBUG.
   # Potential values are ERROR, WARN, INFO, DEBUG, TRACE, OFF, 
   LETSO_LOG=INFO
   ```

1. Start the application:

   ```shell
   docker compose up -d
   ```

1. Access the application at `http://localhost:PORT` typically at <http://localhost:2284> (replace `PORT` with the appropriate port number).

## Contributing

We welcome contributions! Please see the [contributing guide](docs/contributing.md) for more details.

## License

This project is licensed under the Apache-2.0 and/or MIT License. See the LICENSE file for details.
