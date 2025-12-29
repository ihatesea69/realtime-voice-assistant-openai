<a id="readme-top"></a>

<!-- BADGES -->
<p align="center">
  <img src="https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white" />
  <img src="https://img.shields.io/badge/React-61DAFB?style=for-the-badge&logo=react&logoColor=black" />
  <img src="https://img.shields.io/badge/WebRTC-333333?style=for-the-badge&logo=webrtc&logoColor=white" />
  <img src="https://img.shields.io/badge/Pipecat-FF6B6B?style=for-the-badge" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<h1 align="center">Real-time Voice Agent with OpenAI</h1>

<p align="center">
  AI-powered voice assistant for customer support using Pipecat framework with OpenAI Whisper STT, GPT-4o, and TTS. WebRTC-based real-time communication with React UI.
</p>

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Prerequisites](#prerequisites)
5. [Installation](#installation)
6. [Usage](#usage)
7. [Demo Scenario](#demo-scenario)
8. [License](#license)

---

## Overview

A real-time voice agent demonstrating customer support capabilities with:

- Real-time bidirectional voice via WebRTC
- Speech-to-Text using OpenAI Whisper
- LLM responses via GPT-4o-mini
- Text-to-Speech using OpenAI TTS
- Live transcript streaming via WebSocket
- Modern React UI with navy blue theme
- Vietnamese language support

---

## Architecture

```mermaid
graph LR
    subgraph Frontend
        UI[React UI<br/>Vite + Tailwind]
    end

    subgraph Backend
        Server[Pipecat Server<br/>aiohttp]
        STT[OpenAI Whisper<br/>STT]
        LLM[GPT-4o-mini<br/>LLM]
        TTS[OpenAI TTS<br/>TTS]
    end

    UI <-->|WebRTC| Server
    UI <-->|WebSocket| Server
    Server --> STT --> LLM --> TTS --> Server
```

---

## Technology Stack

| Component | Technology     | Purpose                      |
| --------- | -------------- | ---------------------------- |
| Framework | Pipecat AI     | Voice pipeline orchestration |
| STT       | OpenAI Whisper | Speech-to-Text               |
| LLM       | GPT-4o-mini    | Conversation AI              |
| TTS       | OpenAI TTS     | Text-to-Speech               |
| Transport | WebRTC         | Real-time audio streaming    |
| Backend   | aiohttp        | Async HTTP server            |
| Frontend  | React + Vite   | User interface               |
| Styling   | Tailwind CSS   | UI styling                   |

---

## Prerequisites

- Python 3.10+
- Node.js 18+
- OpenAI API Key

---

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/pipecat-openai-voice-agent.git
cd pipecat-openai-voice-agent
```

### 2. Backend Setup

```bash
# Create virtual environment with uv
uv venv
.venv\Scripts\activate  # Windows
# source .venv/bin/activate  # Linux/macOS

# Install dependencies
uv pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY
```

### 3. Frontend Setup

```bash
cd frontend
npm install
```

---

## Usage

### Start Backend

```bash
python main.py
```

Server runs at http://localhost:7860

### Start Frontend

```bash
cd frontend
npm run dev
```

UI runs at http://localhost:5173

### Connect

1. Open http://localhost:5173 in browser
2. Select audio input/output devices
3. Click "Start Conversation"
4. Speak to the voice agent

---

## Demo Scenario

The voice agent demonstrates customer support with:

| Type      | Description               |
| --------- | ------------------------- |
| Product   | Product/service inquiries |
| Order     | Order status checks       |
| Technical | Technical support         |
| Complaint | Complaints and feedback   |
| General   | General questions         |

See [scenario.md](scenario.md) for detailed conversation flow.

---

## Project Structure

```
├── main.py                 # Entry point
├── src/
│   ├── bot.py              # WebRTC server & pipeline
│   ├── flow.py             # Conversation flow logic
│   └── prompt.py           # System & task prompts
├── frontend/
│   └── src/
│       └── App.tsx         # React UI
├── transcripts/            # Saved conversation logs
├── scenario.md             # Demo scenario documentation
└── .env.example            # Environment template
```

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Contact

<p align="center">
  <a href="https://github.com/pipecat-ai/pipecat"><img src="https://img.shields.io/badge/Pipecat_AI-Framework-FF6B6B?style=for-the-badge" /></a>
  <a href="https://platform.openai.com"><img src="https://img.shields.io/badge/OpenAI-API-412991?style=for-the-badge&logo=openai&logoColor=white" /></a>
</p>
