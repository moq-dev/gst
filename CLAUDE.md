# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GStreamer plugin for Media over QUIC (MoQ), written in Rust. It provides `hangsink` and `hangsrc` elements that enable publishing and subscribing to media streams using the MoQ protocol over QUIC transport.

## Development Setup

### Prerequisites
- Rust toolchain (via `rustup`)
- Just command runner
- A running moq-relay server from [moq](https://github.com/kixelated/moq)

### Initial Setup
```bash
# Install dependencies and tools
just setup

# To see all available commands
just
```

## Common Commands

### Building
```bash
# Build the plugin
just build
# or
cargo build
```

### Testing and Quality Checks
```bash
# Run all CI checks (clippy, fmt, cargo check)
just check

# Run tests
just test

# Auto-fix issues
just fix
```

### Development Workflow
```bash
# Start a relay server (in moq repo)
just relay

# Publish video stream with broadcast name
just pub-gst bbb

# Subscribe to video stream with broadcast name
just sub bbb
```

## Architecture

### Plugin Structure
- **lib.rs**: Main plugin entry point, registers both sink and source elements as "hang" plugin
- **sink/**: Hang sink element (`hangsink`) for publishing streams
  - `mod.rs`: GStreamer element wrapper for HangSink
  - `imp.rs`: Core implementation with async Tokio runtime
- **source/**: Hang source element (`hangsrc`) for consuming streams  
  - `mod.rs`: GStreamer element wrapper for HangSrc
  - `imp.rs`: Core implementation with async Tokio runtime

### Key Dependencies
- **hang**: Higher-level hang protocol utilities and CMAF handling
- **moq-mux**: MoQ muxing/demuxing for media streams
- **moq-lite**: Lightweight MoQ protocol types
- **moq-native**: Core MoQ protocol implementation with QUIC/TLS
- **gstreamer**: GStreamer bindings for Rust
- **tokio**: Async runtime (single-threaded worker pool)

### Plugin Elements
- `hangsink`: BaseSink element that accepts media data and publishes via MoQ with broadcast name
- `hangsrc`: Bin element that receives MoQ streams and outputs GStreamer buffers

Both elements use a shared Tokio runtime and support TLS configuration options. They require broadcast names for operation.

## Environment Variables
- `RUST_LOG=info`: Controls logging level
- `URL=http://localhost:4443`: Default relay server URL
- `GST_PLUGIN_PATH`: Must include the built plugin directory

## Notable Changes from moq-gst
- Renamed from moq-gst to hang-gst
- Element names changed from moqsink/moqsrc to hangsink/hangsrc
- Added broadcast parameter requirement for both elements
- Updated justfile commands to include broadcast parameters