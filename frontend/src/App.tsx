import { useState, useEffect, useRef } from 'react';
import { Headphones, Wifi, WifiOff, Bot, Shield, Mic, MicOff, Phone, PhoneOff, ChevronDown } from 'lucide-react';

// Backend host configuration
// Auto-detect protocol (http/https, ws/wss) based on current page
const isSecure = window.location.protocol === 'https:';
const BACKEND_HOST = window.location.hostname;
// When behind Nginx proxy, use same port as frontend (Nginx routes /offer and /ws)
const BACKEND_PORT = isSecure ? '' : ':7860';
const WS_PROTOCOL = isSecure ? 'wss:' : 'ws:';
const HTTP_PROTOCOL = isSecure ? 'https:' : 'http:';

class WebRTCClient {
  private pc: RTCPeerConnection | null = null;
  private localStream: MediaStream | null = null;
  private remoteAudio: HTMLAudioElement | null = null;
  public connected = false;
  public onStateChange?: (state: string) => void;

  constructor() {
    this.pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    });

    this.pc.onconnectionstatechange = () => {
      console.log("Connection state:", this.pc?.connectionState);
      this.connected = this.pc?.connectionState === "connected";
      this.onStateChange?.(this.pc?.connectionState || 'disconnected');
    };

    this.pc.oniceconnectionstatechange = () => {
      console.log("ICE connection state:", this.pc?.iceConnectionState);
    };

    this.pc.ontrack = (event) => {
      console.log("Received track:", event.track.kind);
      if (event.track.kind === "audio") {
        if (!this.remoteAudio) {
          this.remoteAudio = new Audio();
          this.remoteAudio.autoplay = true;
          document.body.appendChild(this.remoteAudio);
        }
        
        const remoteStream = new MediaStream([event.track]);
        this.remoteAudio.srcObject = remoteStream;
        console.log("Audio connected and playing");
      }
    };
  }

  async startBotAndConnect(options: { endpoint: string; audioInput?: string; audioOutput?: string }) {
    try {
      console.log("🎤 Getting user media...");
      const constraints: MediaStreamConstraints = {
        audio: options.audioInput ? { deviceId: { exact: options.audioInput } } : true,
        video: false,
      };
      
      this.localStream = await navigator.mediaDevices.getUserMedia(constraints);

      const transceiver = this.pc?.addTransceiver("audio", {
        direction: "sendrecv"
      });
      console.log("Added audio transceiver:", transceiver?.direction);

      this.localStream.getTracks().forEach((track) => {
        console.log("Adding local audio track:", track.kind);
        this.pc?.addTrack(track, this.localStream!);
      });

      console.log("Creating offer...");
      const offer = await this.pc!.createOffer();
      await this.pc!.setLocalDescription(offer);

      console.log("Sending offer to server...");
      
      const response = await fetch(options.endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          type: offer.type,
          sdp: offer.sdp,
        }),
      });

      if (!response.ok) {
        throw new Error(`Server error: ${response.status} ${response.statusText}`);
      }

      const answer = await response.json();
      console.log("Received answer from server");

      await this.pc!.setRemoteDescription(answer);
      console.log("WebRTC connection established");

      if (options.audioOutput && this.remoteAudio) {
        try {
          if (this.remoteAudio.setSinkId) {
            await this.remoteAudio.setSinkId(options.audioOutput);
          }
        } catch (err) {
          console.warn("Could not set audio output device:", err);
        }
      }

    } catch (error) {
      console.error("Connection failed:", error);
      throw error;
    }
  }

  async updateInputDevice(deviceId: string) {
    if (!this.localStream) return;
    
    try {
      const newStream = await navigator.mediaDevices.getUserMedia({
        audio: { deviceId: { exact: deviceId } },
        video: false
      });
      
      const audioTrack = newStream.getAudioTracks()[0];
      const sender = this.pc?.getSenders().find(s => s.track?.kind === 'audio');
      if (sender) {
        await sender.replaceTrack(audioTrack);
        this.localStream.getAudioTracks().forEach(track => track.stop());
        this.localStream = newStream;
      }
    } catch (err) {
      console.error("Could not update input device:", err);
    }
  }

  async updateOutputDevice(deviceId: string) {
    if (!this.remoteAudio) return;
    
    try {
      if (this.remoteAudio.setSinkId) {
        await this.remoteAudio.setSinkId(deviceId);
      }
    } catch (err) {
      console.error("Could not update output device:", err);
    }
  }

  toggleMute(): boolean {
    if (!this.localStream) return false;
    
    const audioTrack = this.localStream.getAudioTracks()[0];
    if (audioTrack) {
      audioTrack.enabled = !audioTrack.enabled;
      return !audioTrack.enabled; 
    }
    return false;
  }

  get state(): string {
    if (this.pc?.connectionState === 'connected') return 'ready';
    if (this.pc?.connectionState === 'connecting') return 'connecting';
    return 'disconnected';
  }

  disconnect() {
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
      this.localStream = null;
    }
    if (this.remoteAudio) {
      this.remoteAudio.pause();
      this.remoteAudio.srcObject = null;
      if (this.remoteAudio.parentNode) {
        this.remoteAudio.parentNode.removeChild(this.remoteAudio);
      }
      this.remoteAudio = null;
    }
    if (this.pc) {
      this.pc.close();
      this.pc = null;
    }
    this.connected = false;
  }
}

const client = new WebRTCClient();

function MainApp() {
  const [isConnecting, setIsConnecting] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [transcript, setTranscript] = useState<Array<{role: string, content: string}>>([]);
  const [audioDevices, setAudioDevices] = useState<MediaDeviceInfo[]>([]);
  const [selectedInputDevice, setSelectedInputDevice] = useState<string>('');
  const [selectedOutputDevice, setSelectedOutputDevice] = useState<string>('');
  const [inputDropdownOpen, setInputDropdownOpen] = useState(false);
  const [outputDropdownOpen, setOutputDropdownOpen] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);


  useEffect(() => {
    client.onStateChange = (state) => {
      console.log("Client state changed:", state);
      if (state === 'connected') {
        setIsConnected(true);
        setIsConnecting(false);
      } else if (state === 'disconnected' || state === 'failed') {
        setIsConnected(false);
        setIsConnecting(false);
      }
    };
  }, []);


  useEffect(() => {
    let reconnectTimeout: NodeJS.Timeout | null = null;
    
    const connectWebSocket = () => {
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        return; 
      }
      
      const ws = new WebSocket(`${WS_PROTOCOL}//${BACKEND_HOST}${BACKEND_PORT}/ws`);
      
      ws.onopen = () => {
        console.log('WebSocket connected for transcript streaming');
      };
      
      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          if (data.type === 'transcript' && data.message) {
            setTranscript(prev => {
              const isDuplicate = prev.some(msg => 
                msg.role === data.message.role && 
                msg.content === data.message.content
              );
              
              if (isDuplicate) {
                return prev;
              }
              return [...prev, data.message];
            });
          }
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
        }
      };
      
      ws.onerror = (error) => {
        console.error('WebSocket error:', error);
      };
      
      ws.onclose = () => {
        console.log('WebSocket closed');
        wsRef.current = null;
        reconnectTimeout = setTimeout(connectWebSocket, 1000);
      };
      
      wsRef.current = ws;
    };

    connectWebSocket();

    return () => {
      if (reconnectTimeout) {
        clearTimeout(reconnectTimeout);
      }
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
    };
  }, []); 

  useEffect(() => {
    const getDevices = async () => {
      // Check if mediaDevices is available (requires HTTPS on non-localhost)
      if (!navigator.mediaDevices) {
        console.error('navigator.mediaDevices not available. HTTPS required for non-localhost.');
        setError('Microphone access requires HTTPS. Please use HTTPS or access via localhost.');
        return;
      }
      
      try {
        await navigator.mediaDevices.getUserMedia({ audio: true });
        const devices = await navigator.mediaDevices.enumerateDevices();
        setAudioDevices(devices);

        const defaultInput = devices.find(d => d.kind === 'audioinput');
        const defaultOutput = devices.find(d => d.kind === 'audiooutput');
        if (defaultInput) setSelectedInputDevice(defaultInput.deviceId);
        if (defaultOutput) setSelectedOutputDevice(defaultOutput.deviceId);
      } catch (error) {
        console.error('Error getting audio devices:', error);
        setError('Failed to access microphone. Please allow microphone permissions.');
      }
    };

    getDevices();

    if (navigator.mediaDevices) {
      navigator.mediaDevices.addEventListener('devicechange', getDevices);
      return () => {
        navigator.mediaDevices.removeEventListener('devicechange', getDevices);
      };
    }
  }, []);

  const inputDevices = audioDevices.filter(device => device.kind === 'audioinput');
  const outputDevices = audioDevices.filter(device => device.kind === 'audiooutput');


  const handleConnect = async () => {
    if (isConnected) {
      client.disconnect();
      setIsConnected(false);
      setError(null);
      setTranscript([]); 
    } else {
      try {
        setIsConnecting(true);
        setError(null);
        
        await client.startBotAndConnect({
          endpoint: `${HTTP_PROTOCOL}//${BACKEND_HOST}${BACKEND_PORT}/offer`,
          audioInput: selectedInputDevice || undefined,
          audioOutput: selectedOutputDevice || undefined
        });
        
        setIsConnected(true);
      } catch (err) {
        console.error("Connection error:", err);
        setError(err instanceof Error ? err.message : String(err));
        setIsConnected(false);
      } finally {
        setIsConnecting(false);
      }
    }
  };

  const handleDisconnect = () => {
    client.disconnect();
    setIsConnected(false);
    setError(null);
    setTranscript([]);
  };

  const handleToggleMute = () => {
    const muted = client.toggleMute();
    setIsMuted(muted);
  };


  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('.dropdown-container')) {
        setInputDropdownOpen(false);
        setOutputDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-950 to-slate-900">
      {/* Animated background */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute -inset-[10px] opacity-50">
          <div className="absolute top-1/2 left-1/4 w-96 h-96 bg-blue-600 rounded-full mix-blend-multiply filter blur-3xl animate-pulse"></div>
          <div className="absolute top-1/3 right-1/4 w-96 h-96 bg-cyan-600 rounded-full mix-blend-multiply filter blur-3xl animate-pulse delay-700"></div>
          <div className="absolute bottom-1/3 left-1/2 w-96 h-96 bg-indigo-600 rounded-full mix-blend-multiply filter blur-3xl animate-pulse delay-1000"></div>
        </div>
      </div>

      <div className="relative z-10 flex flex-col items-center justify-center min-h-screen p-4">
        {/* Main Container */}
        <div className="w-full max-w-6xl mx-auto">
          {/* Header */}
          <div className="text-center mb-8 animate-slide-up">
            <div className="inline-flex items-center gap-2 bg-white/10 backdrop-blur-xl rounded-full px-4 py-2 mb-4">
              <Shield className="w-4 h-4 text-green-400" />
              <span className="text-xs text-white/80">Secure WebRTC Connection</span>
            </div>
            <h1 className="text-5xl font-bold text-white mb-2 bg-gradient-to-r from-cyan-400 via-blue-400 to-indigo-400 bg-clip-text text-transparent">
              HieuNghi Voice Agent
            </h1>
            <p className="text-xl text-white/70">Customer Support Demo</p>
          </div>

          {/* Main Content Grid */}
          <div className="grid lg:grid-cols-2 gap-6">
            {/* Left Panel - Controls */}
            <div className="space-y-6">
              {/* Connection Card */}
              <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-xl font-semibold text-white flex items-center gap-2">
                    <Bot className="w-6 h-6 text-blue-400" />
                    Voice Assistant
                  </h2>
                  <div className="flex items-center gap-2">
                    {isConnected ? (
                      <>
                        <Wifi className="w-5 h-5 text-green-400" />
                        <span className="text-sm text-green-400">Connected</span>
                      </>
                    ) : (
                      <>
                        <WifiOff className="w-5 h-5 text-gray-400" />
                        <span className="text-sm text-gray-400">Disconnected</span>
                      </>
                    )}
                  </div>
                </div>

                {/* Voice Visualizer */} 
                <div className="h-32 mb-6 bg-black/20 rounded-2xl p-4 flex items-center justify-center">
                  <div className="flex items-center justify-center gap-1 h-full">
                    {[...Array(20)].map((_, i) => (
                      <div
                        key={i}
                        className={`bg-gradient-to-t from-blue-600 to-cyan-400 w-2 rounded-full transition-all duration-100 ${
                          isConnected ? 'animate-pulse' : ''
                        }`}
                        style={{
                          height: isConnected ? `${Math.random() * 100}%` : '10%',
                          opacity: isConnected ? 0.8 : 0.3,
                          animationDelay: `${i * 50}ms`
                        }}
                      />
                    ))}
                  </div>
                </div>

                {error && (
                  <div className="mb-4 p-3 bg-red-500/20 border border-red-500/50 rounded-lg">
                    <p className="text-red-300 text-sm">{error}</p>
                  </div>
                )}

                <div className="space-y-4">
                  {/* Audio Input Device */}
                  <div className="bg-black/20 rounded-xl p-4 dropdown-container">
                    <div className="flex items-center gap-2 mb-3">
                      <Mic className="w-4 h-4 text-cyan-400" />
                      <label className="text-sm font-medium text-white/80">Audio Input Device</label>
                    </div>
                    <div className="relative">
                      <button
                        onClick={() => {
                          setInputDropdownOpen(!inputDropdownOpen);
                          setOutputDropdownOpen(false);
                        }}
                        className="w-full bg-white/10 text-white border border-white/20 rounded-lg px-4 py-2.5 hover:bg-white/20 transition-all focus:outline-none focus:ring-2 focus:ring-blue-500/50 flex items-center justify-between"
                      >
                        <span className="truncate">
                          {inputDevices.find(d => d.deviceId === selectedInputDevice)?.label || 'Select Input Device'}
                        </span>
                        <ChevronDown className={`w-4 h-4 transition-transform ${inputDropdownOpen ? 'rotate-180' : ''}`} />
                      </button>
                      {inputDropdownOpen && (
                        <div className="absolute top-full mt-2 w-full bg-gray-800/95 backdrop-blur-sm border border-white/20 rounded-lg shadow-xl z-50 max-h-60 overflow-y-auto">
                          {inputDevices.map((device) => (
                            <button
                              key={device.deviceId}
                              onClick={() => {
                                setSelectedInputDevice(device.deviceId);
                                setInputDropdownOpen(false);
                                if (isConnected) {
                                  client.updateInputDevice(device.deviceId);
                                }
                              }}
                              className={`w-full text-left px-4 py-2.5 hover:bg-white/10 transition-colors text-white/90 border-b border-white/5 last:border-b-0 ${
                                device.deviceId === selectedInputDevice ? 'bg-blue-600/20' : ''
                              }`}
                            >
                              {device.label || `Microphone ${device.deviceId.slice(0, 8)}`}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Audio Output Device */}
                  <div className="bg-black/20 rounded-xl p-4 dropdown-container">
                    <div className="flex items-center gap-2 mb-3">
                      <Headphones className="w-4 h-4 text-green-400" />
                      <label className="text-sm font-medium text-white/80">Audio Output Device</label>
                    </div>
                    <div className="relative">
                      <button
                        onClick={() => {
                          setOutputDropdownOpen(!outputDropdownOpen);
                          setInputDropdownOpen(false);
                        }}
                        className="w-full bg-white/10 text-white border border-white/20 rounded-lg px-4 py-2.5 hover:bg-white/20 transition-all focus:outline-none focus:ring-2 focus:ring-blue-500/50 flex items-center justify-between"
                      >
                        <span className="truncate">
                          {outputDevices.find(d => d.deviceId === selectedOutputDevice)?.label || 'Select Output Device'}
                        </span>
                        <ChevronDown className={`w-4 h-4 transition-transform ${outputDropdownOpen ? 'rotate-180' : ''}`} />
                      </button>
                      {outputDropdownOpen && (
                        <div className="absolute top-full mt-2 w-full bg-gray-800/95 backdrop-blur-sm border border-white/20 rounded-lg shadow-xl z-50 max-h-60 overflow-y-auto">
                          {outputDevices.map((device) => (
                            <button
                              key={device.deviceId}
                              onClick={() => {
                                setSelectedOutputDevice(device.deviceId);
                                setOutputDropdownOpen(false);
                                if (isConnected) {
                                  client.updateOutputDevice(device.deviceId);
                                }
                              }}
                              className={`w-full text-left px-4 py-2.5 hover:bg-white/10 transition-colors text-white/90 border-b border-white/5 last:border-b-0 ${
                                device.deviceId === selectedOutputDevice ? 'bg-green-600/20' : ''
                              }`}
                            >
                              {device.label || `Speaker ${device.deviceId.slice(0, 8)}`}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Action Buttons */}
                  <div className="grid grid-cols-2 gap-3">
                    {isConnected && (
                      <button
                        onClick={handleToggleMute}
                        className={`${
                          isMuted 
                            ? 'bg-red-600/80 hover:bg-red-700 border-red-500/30' 
                            : 'bg-blue-600/80 hover:bg-blue-700 border-blue-500/30'
                        } text-white rounded-xl py-3 px-4 font-medium transition-all flex items-center justify-center gap-2 backdrop-blur-sm border`}
                      >
                        {isMuted ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
                        <span>{isMuted ? 'Unmute' : 'Mute'}</span>
                      </button>
                    )}
                  </div>

                  {/* Connect Button */}
                  <div className="relative group">
                    <div className="absolute inset-0 bg-gradient-to-r from-cyan-600 to-blue-600 rounded-xl opacity-75 blur group-hover:opacity-100 transition-opacity"></div>
                    <button
                      onClick={isConnected ? handleDisconnect : handleConnect}
                      disabled={isConnecting}
                      className={`relative w-full ${
                        isConnecting 
                          ? 'bg-orange-600/90 animate-pulse' 
                          : isConnected 
                            ? 'bg-red-600/90 hover:bg-red-700 border-red-500/30' 
                            : 'bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-700 hover:to-blue-700 border-white/20'
                      } backdrop-blur-sm text-white rounded-xl py-4 px-6 font-semibold transition-all shadow-2xl flex items-center justify-center gap-3 border`}
                    >
                      {isConnecting ? (
                        <>
                          <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                          <span>Connecting...</span>
                        </>
                      ) : isConnected ? (
                        <>
                          <PhoneOff className="w-5 h-5" />
                          <span>End Conversation</span>
                        </>
                      ) : (
                        <>
                          <Phone className="w-5 h-5" />
                          <span>Start Conversation</span>
                        </>
                      )}
                    </button>
                  </div>
                </div>
              </div>

            </div>

            {/* Right Panel - Transcript */}
            <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl h-[600px] flex flex-col">
              <h2 className="text-xl font-semibold text-white mb-4">Conversation</h2>
              
              <div className="flex-1 overflow-hidden rounded-2xl bg-black/20">
                <div className="h-full overflow-y-auto p-4 space-y-3">
                  {transcript.map((message, index) => (
                    <div
                      key={index}
                      className={`rounded-lg p-3 text-white/90 animate-slide-up ${
                        message.role === 'user' 
                          ? 'bg-cyan-600/20 ml-8' 
                          : 'bg-blue-600/20 mr-8'
                      }`}
                    >
                      <div className="text-xs text-white/50 mb-1">
                        {message.role === 'user' ? 'Customer' : 'Assistant'}
                      </div>
                      <div>{message.content}</div>
                    </div>
                  ))}
                </div>
                
                {transcript.length === 0 && (
                  <div className="h-full flex items-center justify-center">
                    <p className="text-white/40 text-center">
                      Start a conversation to see the transcript here
                    </p>
                  </div>
                )}
              </div>

              {/* Status Bar */}
              <div className="mt-4 pt-4 border-t border-white/10">
                <div className="flex items-center justify-between text-xs text-white/60">
                  <span>Pipecat AI</span>
                  <span>OpenAI Whisper - GPT-4o - TTS</span>
                </div>
              </div>
            </div>
          </div>

          {/* Footer */}
          <div className="mt-8 text-center text-white/60 text-sm">
            <p>© 2025 HieuNghi Voice Agent - Customer Support Demo</p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default MainApp;