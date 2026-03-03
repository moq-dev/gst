#!/usr/bin/env just --justfile

# Using Just: https://github.com/casey/just?tab=readme-ov-file#installation

export RUST_BACKTRACE := "1"
export RUST_LOG := env_var_or_default("RUST_LOG", "info")
export URL := "http://localhost:4443/anon"
#export GST_DEBUG:="*:4"

# List all of the available commands.
default:
  just --list

# Install any required dependencies.
setup:
	# Upgrade Rust
	rustup update

	# Make sure the right components are installed.
	rustup component add rustfmt clippy

	# Install cargo binstall if needed.
	cargo install cargo-binstall

	# Install cargo shear if needed.
	cargo binstall --no-confirm cargo-shear

# Returns the URL for a test video.
download-url name:
	@case {{name}} in \
		bbb) echo "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" ;; \
		tos) echo "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4" ;; \
		av1) echo "http://download.opencontent.netflix.com.s3.amazonaws.com/AV1/Sparks/Sparks-5994fps-AV1-10bit-1920x1080-2194kbps.mp4" ;; \
		hevc) echo "https://test-videos.co.uk/vids/jellyfish/mp4/h265/1080/Jellyfish_1080_10s_30MB.mp4" ;; \
		*) echo "unknown: {{name}}" && exit 1 ;; \
	esac

# Download a test video and convert it to a fragmented MP4.
download name:
	@if [ ! -f "dev/{{name}}.mp4" ]; then \
		curl -fsSL $(just download-url {{name}}) -o "dev/{{name}}.mp4"; \
	fi

	@if [ ! -f "dev/{{name}}.fmp4" ]; then \
		ffmpeg -i "dev/{{name}}.mp4" \
			-c copy \
			-f mp4 -movflags cmaf+separate_moof+delay_moov+skip_trailer+frag_every_frame \
			"dev/{{name}}.fmp4"; \
	fi

# Publish a video using gstreamer to the localhost relay server
pub broadcast name="bbb":
	just download "{{name}}"

	# Build the plugins
	cargo build

	# Run gstreamer and pipe the output to our plugin.
	# NOTE: `identity sync=true` throttles to real-time since we're using a file source.
	# A real livestream source would not need this; you want to publish frames ASAP.
	GST_PLUGIN_PATH_1_0="${PWD}/target/debug${GST_PLUGIN_PATH_1_0:+:$GST_PLUGIN_PATH_1_0}" \
	gst-launch-1.0 -v -e multifilesrc location="dev/{{name}}.fmp4" loop=true ! qtdemux name=demux \
		demux.video_0 ! h264parse config-interval=-1 ! queue ! identity sync=true ! mux.video_0 \
		demux.audio_0 ! aacparse ! queue ! identity sync=true ! mux.audio_0 \
		moqsink name=mux url="$URL" broadcast="{{broadcast}}" tls-disable-verify=true

# Subscribe to a video using gstreamer
sub broadcast:
	# Build the plugins
	cargo build

	# Run gstreamer and pipe the output to our plugin
	# This will render the video to the screen
	GST_PLUGIN_PATH_1_0="${PWD}/target/debug${GST_PLUGIN_PATH_1_0:+:$GST_PLUGIN_PATH_1_0}" \
	gst-launch-1.0 -v -e moqsrc url="$URL" broadcast="{{broadcast}}" tls-disable-verify=true ! decodebin ! videoconvert ! autovideosink

# Run the CI checks
check $RUSTFLAGS="-D warnings":
	cargo check --all-targets
	cargo clippy --all-targets -- -D warnings
	cargo fmt -- --check
	cargo shear # requires: cargo binstall cargo-shear

# Run any CI tests
test $RUSTFLAGS="-D warnings":
	cargo test

# Automatically fix some issues.
fix:
	cargo fix --allow-staged --all-targets --all-features
	cargo clippy --fix --allow-staged --all-targets --all-features
	cargo fmt --all
	cargo shear --fix

# Upgrade any tooling
upgrade:
	rustup upgrade

	# Install cargo-upgrades if needed.
	cargo install cargo-upgrades cargo-edit
	cargo upgrade

# Build the plugins
build:
	cargo build
