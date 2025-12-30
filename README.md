<a id="readme-top"></a>

<!-- BADGES -->
<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white" />
  <img src="https://img.shields.io/badge/React-61DAFB?style=for-the-badge&logo=react&logoColor=black" />
  <img src="https://img.shields.io/badge/WebRTC-333333?style=for-the-badge&logo=webrtc&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<h1 align="center">HieuNghi Voice Agent</h1>

<p align="center">
  A robust, real-time customer support voice agent built with <b>Pipecat</b> and <b>OpenAI</b>.
  <br />
  Features low-latency WebRTC audio, comprehensive deployment scripts (Docker + Terraform), and Vietnamese language support.
</p>

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Features](#features)
4. [Prerequisites](#prerequisites)
5. [Local Development](#local-development)
6. [Deployment on AWS (Terraform)](#deployment-on-aws-terraform)
7. [WebRTC & TURN Configuration](#webrtc--turn-configuration)
8. [Project Structure](#project-structure)
9. [Changelog](#changelog)

---

## Overview

**HieuNghi Voice Agent** replaces legacy systems with a modern, AI-driven stack. It handles customer support scenarios such as product inquiries, order checking, and technical support via natural voice conversation.

**Key capabilities:**

- **Full Duplex Audio**: Speak and listen simultaneously.
- **Vietnamese Support**: Optimized prompts and TTS for Vietnamese customers.
- **Production Ready**: Includes Nginx reverse proxy, SSL setup, and infrastructure-as-code.

---

## Architecture

```mermaid
graph LR
    subgraph Client
        Browser[React Frontend]
    end

    subgraph AWS EC2
        Nginx[Nginx Reverse Proxy]
        Backend[Python Pipecat Server]
    end

    subgraph External Services
        OpenAI[OpenAI API<br/>(Whisper/GPT-4o/TTS)]
        Metered[Metered.ca TURN]
    end

    Browser <-->|HTTPS/WSS| Nginx
    Nginx <-->|HTTP/WS| Backend
    Browser <-->|WebRTC (UDP/TCP)| Backend
    Browser -.->|TURN Relay| Metered
    Backend -.->|TURN Relay| Metered
    Backend <-->|API| OpenAI
```

---

## Features

- **OpenAI Stack**:
  - **STT**: OpenAI Whisper
  - **LLM**: GPT-4o-mini (Context-aware customer support persona)
  - **TTS**: OpenAI TTS (hd quality)
- **UI/UX**:
  - Professional Navy Blue theme.
  - Real-time audio visualization.
  - Streaming transcripts.
- **Infrastructure**:
  - **Docker**: Full containerization.
  - **Terraform**: One-click infrastructure provisioning.
  - **Networking**: TURN (TCP/UDP) support for reliable connections behind firewalls.

---

## Prerequisites

- **Docker** & **Docker Compose**
- **OpenAI API Key**
- **Metered.ca Account** (Free tier) for TURN credentials (optional for local, required for cloud).

---

## Local Development

1. **Clone the repository:**

   ```bash
   git clone https://github.com/ihatesea69/realtime-voice-assistant-openai.git
   cd realtime-voice-assistant-openai
   ```

2. **Configure Environment:**

   ```bash
   cp .env.example .env
   # Edit .env and enter your OPENAI_API_KEY
   ```

3. **Start with Docker (Recommended):**

   ```bash
   docker-compose up --build
   ```

4. **Access:**
   - Frontend: `http://localhost:5173`
   - Backend API: `http://localhost:7860`

---

## Deployment on AWS (Terraform)

This project includes a production-ready Terraform configuration to deploy to AWS EC2.

### 1. Setup Terraform Variables

Navigate to the `terraform/` directory and configure your secrets.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region      = "ap-southeast-1"
key_name        = "your-aws-keypair"
openai_api_key  = "sk-..."
turn_username   = "your-metered-username"
turn_credential = "your-metered-credential"
domain_name     = "your-domain.com"
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform apply
```

_This will provision an EC2 instance, Security Group, and automatically install Docker, Nginx, and the Application._

### 3. Setup SSL (HTTPS)

SSH into your new instance (IP output by Terraform):

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

Run the prepared SSL setup script (ensure your DNS A record points to the IP first):

```bash
sudo ./setup_ssl.sh
```

---

## WebRTC & TURN Configuration

WebRTC often fails in cloud environments due to NAT/Firewalls. We solved this by:

1.  **TURN Server**: Integrating Metered.ca.
2.  **TCP Transport**: Configuring `transport=tcp` on port 443 to mimic HTTPS traffic, bypassing most firewall restrictions.
3.  **ICE Gathering Wait**: The Frontend explicitly waits for ICE gathering to complete before sending an offer, ensuring the Backend receives valid candidate IP addresses.

**Configuration in `src/bot.py` and `frontend/src/App.tsx`**:

```python
IceServer(
    urls="turn:global.relay.metered.ca:443?transport=tcp",
    username=...,
    credential=...
)
```

---

## Project Structure

```
├── .env.example            # Environment template
├── CHANGELOG.md            # Version history
├── Dockerfile              # Backend container definition
├── docker-compose.yml      # Local dev orchestration
├── docker-compose.prod.yml # (Generated on EC2) Production orchestration
├── main.py                 # App Entry point
├── requirements.txt        # Python dependencies
├── src/
│   ├── bot.py              # Core logic: WebRTC, Pipeline, TURN
│   ├── flow.py             # Conversation flow & handlers
│   └── prompt.py           # System prompts & persona
├── frontend/
│   ├── Dockerfile          # Frontend container
│   ├── src/                # React Source
│   └── vite.config.ts      # Vite config
└── terraform/              # Infrastructure as Code
    ├── main.tf             # AWS Resources
    ├── variables.tf        # Variable definitions
    └── user_data.sh        # Provisioning script (Nginx/Docker/Env)
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## License

Distributed under the MIT License.
