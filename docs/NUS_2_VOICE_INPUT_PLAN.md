# NUS 2.0 Voice Input — implementation boundary

1. The voice adapter is provider-isolated.
2. `ar-EG` is the default locale for Egyptian Arabic capture.
3. Voice is short-command oriented, not continuous dictation.
4. Audio is not persisted by NUS.
5. Transcribed text must be reviewed/processed by the existing Quick Add parser before persistence.
6. Existing reminder scheduling remains the only persistence path.
7. Microphone/query permissions must be explicitly declared for Android.
