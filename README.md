# ClearVoice — Audio Noise Reduction Studio

A local R Shiny application for reducing background noise in WAV recordings using classical signal processing.

## Features
- Upload WAV audio (up to 100 MB by default).
- Spectral noise reduction using an estimated noise profile.
- Optional high-pass filtering and low-level noise gate.
- Original/cleaned waveform and frequency-spectrum comparisons.
- Browser playback and WAV download.

## Requirements
- R 4.1 or newer
- Internet only for installing packages the first time; audio processing runs locally.

## Install packages
Open R or RStudio in this folder and run:

```r
install.packages(c("shiny", "tuneR", "signal", "ggplot2", "jsonlite"))
```

## Run

```r
shiny::runApp("app.R")
```

The app opens in your browser. Upload a WAV file, select settings, and click **Clean audio**.

## Notes and limitations
- WAV is supported directly. Convert MP3/M4A to WAV first using a trusted audio converter or FFmpeg.
- Spectral gating can create musical-noise artifacts and may suppress quiet speech. Try several strength values.
- The noise profile is estimated from the start of the clip, so a short noise-only opening improves results.
- This is traditional signal processing, not a neural-network denoiser. For best results on complex speech, a pretrained speech-enhancement model would be a separate optional integration.
