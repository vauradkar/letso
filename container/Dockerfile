# ----------------------------------------------------------------------------------
# STAGE 1: Backend Dependencies (for caching)
# This stage only builds the dependencies, which change less often than the code.
# ----------------------------------------------------------------------------------
FROM rust:1.90 AS backend-deps

WORKDIR /app

# Copy only the manifest files first
COPY Cargo.toml Cargo.lock ./
COPY shlib/Cargo.toml ./shlib/
COPY server/Cargo.toml ./server/

# Create a dummy src/main.rs to force cargo to download and build dependencies
# This is the standard Rust "caching trick"
RUN mkdir -p server/src/
RUN echo "//! placeholder main \n fn main() {}" > server/src/main.rs
RUN mkdir -p shlib/src/
RUN echo "//! placeholder lib" > shlib/src/lib.rs

# Build dependencies (and throw away the dummy build)
# The result is that the /usr/local/cargo cache is populated.
RUN cargo build --release
RUN rm -rf src/

# ----------------------------------------------------------------------------------
# STAGE 2: Backend Builder (Leveraging cached dependencies)
# ----------------------------------------------------------------------------------
FROM backend-deps AS backend-builder

# Copy the source code now (this invalidates the cache after Stage 1 if code changes)
COPY . .
RUN touch shlib/src/lib.rs server/src/main.rs

# Build the Rust backend
# This will reuse the dependencies built in Stage 1, making this step much faster
RUN cargo build --release

# ----------------------------------------------------------------------------------
# STAGE 3: Frontend Builder (Flutter Packages Caching)
# ----------------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS frontend-builder

WORKDIR /app/
COPY ./ui .

# Copy pubspec.yaml and pubspec.lock first
COPY ./ui/pubspec.yaml ./ui/pubspec.lock ./

# Get packages (this is the key caching step for Flutter)
# This layer is only invalidated if pubspec files change
RUN flutter pub get

# Now copy the rest of the source files
COPY ./ui .

# Build Flutter web app
RUN flutter build web

# ----------------------------------------------------------------------------------
# STAGE 4: Final Image (Minimal)
# ----------------------------------------------------------------------------------
FROM debian:bookworm-slim

# Install ca-certificates required for most communication
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /letso/bin /letso/ui

# Copy backend binary
# Use 'server' binary (Rust builds an executable named after the package name in Cargo.toml)
COPY --from=backend-builder /app/target/release/server /letso/bin/

# Copy frontend build
COPY --from=frontend-builder /app/build/web /letso/ui/

# User, Permissions, and Metadata
VOLUME /data
EXPOSE 2284

# Set entrypoint
ENTRYPOINT ["/letso/bin/server", "--upload-root", "/data/", "--ui-dir", "/letso/ui/", "--port", "2284", "--bind", "0.0.0.0"]
