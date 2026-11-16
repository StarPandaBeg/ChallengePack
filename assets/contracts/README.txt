Original downloaded Kenney Interface Sounds (1.0) files, CC0.
Source, mirror and license: ../../ChallengePack/src/assets/contracts/CREDITS.txt

Prepare the bundled WAV files from the repository root with FFmpeg:
ffmpeg -i assets/contracts/confirmation_002.ogg -ac 1 -ar 44100 -c:a pcm_s16le ChallengePack/src/assets/contracts/armed.wav
ffmpeg -i assets/contracts/error_006.ogg -ac 1 -ar 44100 -c:a pcm_s16le ChallengePack/src/assets/contracts/breach.wav

The prepared WAV files are committed; FFmpeg is unnecessary for ordinary builds.
