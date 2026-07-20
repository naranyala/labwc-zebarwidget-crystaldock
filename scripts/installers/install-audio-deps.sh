#!/bin/bash
# Install audio visualization dependencies (PulseAudio/PipeWire and FFTW3)

set -e

if [ -f /etc/os-release ]; then
    . /etc/os-release
fi

echo "Installing audio visualizer dependencies..."

if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "${ID_LIKE:-}" == *"debian"* || "${ID_LIKE:-}" == *"ubuntu"* ]]; then
    pkexec apt update
    pkexec apt install -y libfftw3-dev libpulse-dev libcairo2-dev
elif [[ "$ID" == "arch" || "${ID_LIKE:-}" == *"arch"* ]]; then
    pkexec pacman -S --needed fftw libpulse cairo
elif [[ "$ID" == "fedora" || "${ID_LIKE:-}" == *"fedora"* ]]; then
    pkexec dnf install -y fftw-devel pulseaudio-libs-devel cairo-devel
else
    echo "Please manually install the development headers for: fftw3, pulse, cairo"
fi

echo "Audio dependencies installed successfully!"
