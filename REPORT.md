# Project Report: ClearVoice — Audio Noise Reduction Studio

## Abstract
ClearVoice is an interactive audio processing application developed in R using Shiny. It is designed to reduce steady background noise from recorded speech and audio. The application accepts WAV files, estimates a noise profile from the opening frames, attenuates frequency components associated with the estimated noise, and optionally applies a high-pass filter and a low-level noise gate. The user can inspect waveform and frequency-spectrum plots, listen to the original and processed audio, and download the output WAV file. The project demonstrates digital signal processing and interactive application development in R.

## 1. Problem Statement
Recorded audio can contain fan noise, electrical hum, room rumble, or other background sounds. These sounds can reduce intelligibility and make recordings less suitable for presentations, interviews, and online learning. A simple, accessible tool is useful for experimenting with noise-reduction settings and comparing results.

## 2. Objectives
1. Provide a browser-based interface for loading WAV recordings.
2. Implement spectral noise reduction and optional filtering.
3. Visualize the original and processed waveforms and frequency spectra.
4. Provide audio playback and downloadable output.
5. Keep processing local to the user's R session.

## 3. Existing System and Proposed System
Manual editing tools can be difficult for beginners or may require paid software. ClearVoice provides a focused interface with adjustable settings and visual feedback. It uses conventional signal-processing techniques; it does not claim to be a trained deep-learning model.

## 4. System Requirements
**Software:** R 4.1+, RStudio (recommended), Shiny, tuneR, signal, ggplot2, jsonlite, and a modern browser.

**Hardware:** A computer with 4 GB RAM recommended; more memory is helpful for long recordings. WAV files are processed in memory.

## 5. Methodology
1. Upload and decode a WAV recording.
2. Convert stereo audio to mono for processing.
3. Divide the waveform into overlapping frames and apply a window.
4. Estimate a magnitude noise profile from the first frames.
5. Subtract a scaled noise estimate from each frame's magnitude spectrum while retaining phase.
6. Reconstruct frames using inverse FFT and overlap-add.
7. Optionally apply high-pass filtering and a low-level gate.
8. Normalize the output, visualize it, play it, and export a WAV file.

## 6. Modules
- **File Upload Module:** accepts WAV audio and checks file format.
- **Noise Reduction Module:** applies spectral attenuation.
- **Filter Module:** offers high-pass filtering and a low-level gate.
- **Visualization Module:** plots waveforms and frequency spectra.
- **Playback and Export Module:** plays input/output and writes a cleaned WAV file.

## 7. Algorithm
1. Start the application.
2. Upload a WAV recording.
3. Read the samples and sample rate.
4. Estimate the noise spectrum from the beginning of the recording.
5. Attenuate noise-dominated frequency bins.
6. Reconstruct the signal and apply optional filters.
7. Normalize and display plots.
8. Play or download the result.
9. Stop.

## 8. Testing and Results
Test using recordings containing steady fan noise, room noise, or low-level hiss. Compare the waveform and spectrum before and after processing, and listen to both versions. Results depend on the recording and selected parameters; excessive reduction can distort quiet speech. No universal quality score is reported because a clean reference recording is not automatically available.

## 9. Future Enhancements
- Add stereo-preserving processing.
- Add MP3/M4A conversion through FFmpeg.
- Add voice activity detection and noise-profile selection.
- Integrate an optional pretrained neural speech-enhancement model.

## Conclusion
ClearVoice demonstrates how R can be used to build an interactive audio restoration tool. It combines file handling, FFT-based processing, visualization, playback, and export in a single Shiny application.
