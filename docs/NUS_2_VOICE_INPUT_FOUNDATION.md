# NUS 2.0 Voice Input Foundation

## Goal
Add voice-first capture without introducing a second task/reminder system. Voice must feed the existing Quick Add/reminder flow and remain optional.

## First slice
- Keep current text Quick Add intact.
- Add a platform capability layer for speech recognition behind an interface.
- Keep UI state deterministic: idle, listening, processing, success, unavailable, error.
- Do not persist audio.
- Do not auto-submit uncertain transcription.
- Preserve Arabic/Egyptian use cases and allow future locale configuration.
- No new package is added in this foundation slice until the repository's current Android/iOS configuration and dependency state are inspected.

## Acceptance
1. Existing tests remain green.
2. Voice capability is injectable/mocked in tests.
3. UI can render unavailable/error states without native speech support.
4. No existing reminder persistence or notification code is replaced.
5. Follow-up implementation may add a speech package only after version/platform compatibility is verified.
