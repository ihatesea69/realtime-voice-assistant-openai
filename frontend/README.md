# CX Genie React UI

A modern, beautiful React interface for the CX Genie Vietnamese Customer Service Voicebot.

## Features

✨ **Beautiful UI Components**
- Modern gradient design with glass morphism effects
- Smooth animations and transitions
- Real-time audio visualization
- Connection status indicators
- Error handling and display

🎙️ **Voice Controls**
- One-click start/stop conversation
- Mute/unmute microphone
- Visual feedback for audio activity
- Connection state management

🔊 **Audio Features**
- WebRTC audio streaming
- Bidirectional audio support
- Echo cancellation & noise suppression
- Automatic audio playback

## Tech Stack

- **React 19** - Latest React version
- **TypeScript** - Type-safe development
- **Tailwind CSS 4** - Utility-first CSS framework
- **Pipecat Voice UI Kit** - Voice interface components
- **WebRTC** - Real-time communication
- **Lucide Icons** - Beautiful icon library
- **Vite** - Fast build tool

## Installation

```bash
npm install
```

## Development

```bash
npm run dev
```

The UI will be available at `http://localhost:5173`

## Build

```bash
npm run build
```

## Project Structure

```
src/
├── components/          # UI components
│   ├── VoiceInterface.tsx   # Main voice interface
│   └── TranscriptView.tsx   # Conversation transcript
├── lib/                 # Utility functions
│   └── utils.ts        # Helper functions
├── App.tsx             # Main app with WebRTC
├── AppWithVoiceUIKit.tsx  # Alternative with Voice UI Kit
├── index.css           # Tailwind CSS styles
└── main.tsx            # Application entry point
```

## UI Components

### VoiceInterface
Main interface component with:
- Connection controls
- Status display
- Audio visualization
- Mute controls
- Error handling

### TranscriptView
Shows conversation history with:
- User/bot message bubbles
- Timestamps
- Auto-scroll
- Avatar icons

### WebRTCClient
Custom WebRTC implementation:
- Peer connection management
- Audio stream handling
- Connection state tracking
- Error handling

## Styling

The UI uses:
- **Gradients**: Blue to purple theme
- **Glass morphism**: Backdrop blur effects
- **Animations**: Smooth transitions
- **Responsive**: Mobile-friendly design

## Configuration

WebRTC endpoint is configured in `App.tsx`:
```typescript
await clientRef.current.connect("http://localhost:7860/offer");
```

## Browser Support

- Chrome/Edge (recommended)
- Firefox
- Safari (with limitations)

Requires microphone permissions.
