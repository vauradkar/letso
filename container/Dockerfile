# Use official Rust image to build the backend
FROM rust:1.90 AS backend-builder

WORKDIR /app
COPY . .

# RUN ls -la /app
# RUN ls -la .

# Build the Rust backend (assumes Cargo.toml is in root)
RUN cargo build --release

# Use official Flutter image to build the frontend
FROM ghcr.io/cirruslabs/flutter:stable AS frontend-builder

WORKDIR /app/
COPY ./ui .
# RUN ls -la /app/

RUN flutter --version 
RUN flutter doctor

# Build Flutter web app (assumes web target)
RUN flutter build web
# RUN ls -la /app/.

# Final image
FROM debian:bookworm-slim

# Create directories
RUN mkdir -p /letso/bin /letso/ui

# Copy backend binary
COPY --from=backend-builder /app/target/release/server /letso/bin/

# Copy frontend build
COPY --from=frontend-builder /app/build/web /letso/ui/


VOLUME /data
EXPOSE 2284
# Set entrypoint (adjust as needed)
ENTRYPOINT ["/letso/bin/server", "--base-dir", "/data/", "--app-dir", "/letso/ui/", "--port", "2284", "--bind", "0.0.0.0"]
