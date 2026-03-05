---
name: speech-to-text
description: >
  Transcribe audio files (OGG, MP3, WAV, M4A, FLAC, etc.) using whisper-cpp locally with Metal GPU.
  Use when: (1) user provides an audio file to transcribe, (2) user asks "what does this
  audio say?", (3) user drops a voice memo or recording.
---

# Speech-to-Text (Whisper)

## Quick Use — Wrapper Script (Preferred)

```bash
./scripts/transcribe.sh /path/to/audio.ogg          # uses small model, outputs plain text
./scripts/transcribe.sh /path/to/audio.ogg medium    # for noisy audio
```

Handles any audio format, converts to 16kHz WAV automatically, runs whisper-cpp with Metal GPU.
~12s for a 5-min file with `small`.

## Direct CLI

**whisper-cpp** (fast, Metal GPU — preferred):
```bash
ffmpeg -i input.ogg -ar 16000 -ac 1 -c:a pcm_s16le /tmp/input.wav
whisper-cli -m ~/.local/share/whisper-cpp/models/ggml-small.bin -f /tmp/input.wav -otxt -of /tmp/output
```

**Python whisper** (slower, but accepts any format directly):
```bash
whisper /path/to/audio.ogg --model small --output_format txt
```

- **Use `small` by default** — 3.3x faster than `medium` with nearly identical accuracy on clear speech
- Use `medium` only for noisy audio, heavy accents, or when accuracy is critical
- Whisper auto-detects language. Use `--language en` to force English if needed
- Supported formats: OGG, MP3, WAV, M4A, FLAC, WEBM, and more (anything ffmpeg handles)

## Output Formats

- `--output_format txt` — plain text (default choice)
- `--output_format srt` — subtitles with timestamps
- `--output_format json` — structured with word-level timestamps
- `--output_format all` — generates all formats

## Key Notes

- Whisper is **cold-start only** — no daemon, no background RAM usage. Loads model, transcribes, exits.
- `small` model uses ~1GB RAM while running; `medium` uses ~2-3GB
- whisper-cpp GGML models stored at `~/.local/share/whisper-cpp/models/ggml-{size}.bin`
