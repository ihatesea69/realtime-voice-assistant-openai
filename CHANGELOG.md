# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-12-30

### Added

- **AWS Deployment**: Complete Terraform configuration (`terraform/`) for deploying to AWS EC2.
  - Automated Nginx reverse proxy setup (Port 80/443).
  - Automated SSL setup preparation (Certbot).
  - Secure Security Group configuration (SSH, HTTP/S, WebRTC UDP).
- **WebRTC TURN Support**: Integrated Metered.ca TURN servers with TCP transport on port 443 for reliable connectivity behind firewalls.
- **Docker Support**: Full Dockerization for both Frontend (Node -> Nginx) and Backend (Python/Pipecat).
- **Environment Management**: Added `terraform/user_data.sh` to automatically inject environment variables on deployment.

### Changed

- **Rebranding**: Renamed project from "CX Genie" to "HieuNghi Voice Agent".
- **Tech Stack**: Switched to an all-OpenAI stack (Whisper STT, GPT-4o LLM, OpenAI TTS), removing dependencies on Deepgram, Twilio, and Cartesia.
- **UI Theme**: Updated Frontend to a professional Navy Blue theme.
- **WebRTC Logic**: Implemented `waitForIceGathering` in Frontend to ensure successful connection establishment by waiting for TURN candidates.
- **Backend Protocol**: Enforced TCP-only TURN candidates for better compatibility with restricted networks.

### Fixed

- **WebRTC Audio**: Resolved "ICE checking" stuck state by ensuring SDP offers contain valid public candidates (Critical Fix).
- **Autoplay Policy**: Implemented explicit user interaction handling for audio playback on modern browsers.
- **WebSocket Protocol**: Fixed mixed content issues by dynamically switching between `ws://` and `wss://`.
- **Cors/Origin**: Updated Vite config to allow all hosts for EC2 deployment.

### Removed

- Legacy files (`utils/`, `apps/`, `twilio_bot.py`).
- Unused assets and audio files.
