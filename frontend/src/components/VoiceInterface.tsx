import { useState, useEffect } from 'react';
import { Mic, MicOff, PhoneCall, PhoneOff, Activity, Loader2, AlertCircle } from 'lucide-react';
import { cn } from '../lib/utils';

interface VoiceInterfaceProps {
  isConnected: boolean;
  isConnecting: boolean;
  isMuted: boolean;
  error?: string | null;
  onConnect: () => void;
  onDisconnect: () => void;
  onToggleMute: () => void;
}

export function VoiceInterface({
  isConnected,
  isConnecting,
  isMuted,
  error,
  onConnect,
  onDisconnect,
  onToggleMute
}: VoiceInterfaceProps) {
  const [audioLevel, setAudioLevel] = useState(0);
  
  // Simulate audio level animation when connected
  useEffect(() => {
    if (!isConnected) return;
    
    const interval = setInterval(() => {
      setAudioLevel(Math.random() * 100);
    }, 100);
    
    return () => clearInterval(interval);
  }, [isConnected]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Main Card */}
        <div className="bg-white/80 backdrop-blur-xl rounded-3xl shadow-2xl border border-gray-100 overflow-hidden">
          {/* Header */}
          <div className="bg-gradient-to-r from-blue-600 to-purple-600 p-6 text-white">
            <h1 className="text-2xl font-bold text-center mb-2">
              CX Genie AI Bot
            </h1>
            <p className="text-center text-blue-100 text-sm">
              Renova Cloud
            </p>
          </div>

          {/* Status Section */}
          <div className="p-6 border-b border-gray-100">
            <div className="flex items-center justify-between mb-4">
              <span className="text-gray-600 font-medium">Status</span>
              <div className="flex items-center gap-2">
                <span className={cn(
                  "inline-block w-2 h-2 rounded-full",
                  isConnected ? "bg-green-500 animate-pulse" : "bg-gray-400"
                )} />
                <span className={cn(
                  "text-sm font-medium",
                  isConnected ? "text-green-600" : "text-gray-500"
                )}>
                  {isConnecting ? "Connecting..." : isConnected ? "Connected" : "Disconnected"}
                </span>
              </div>
            </div>

            {/* Audio Visualizer */}
            {isConnected && (
              <div className="flex items-center justify-center gap-1 h-16">
                {[...Array(20)].map((_, i) => (
                  <div
                    key={i}
                    className="bg-gradient-to-t from-blue-500 to-purple-500 w-2 rounded-full transition-all duration-100"
                    style={{
                      height: `${Math.max(10, (audioLevel + Math.sin(i + audioLevel) * 30))}%`,
                      opacity: 0.8
                    }}
                  />
                ))}
              </div>
            )}

            {/* Error Display */}
            {error && (
              <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg flex items-start gap-2">
                <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-sm font-medium text-red-800">Connection Error</p>
                  <p className="text-xs text-red-600 mt-1">{error}</p>
                </div>
              </div>
            )}
          </div>

          {/* Controls Section */}
          <div className="p-6 space-y-4">
            {/* Mute Button */}
            {isConnected && (
              <button
                onClick={onToggleMute}
                className={cn(
                  "w-full py-3 px-4 rounded-xl flex items-center justify-center gap-3 font-medium transition-all",
                  "border-2",
                  isMuted 
                    ? "bg-red-50 border-red-200 text-red-700 hover:bg-red-100"
                    : "bg-gray-50 border-gray-200 text-gray-700 hover:bg-gray-100"
                )}
              >
                {isMuted ? (
                  <>
                    <MicOff className="w-5 h-5" />
                    <span>Microphone Muted</span>
                  </>
                ) : (
                  <>
                    <Mic className="w-5 h-5" />
                    <span>Microphone Active</span>
                  </>
                )}
              </button>
            )}

            {/* Connect/Disconnect Button */}
            <button
              onClick={isConnected ? onDisconnect : onConnect}
              disabled={isConnecting}
              className={cn(
                "w-full py-4 px-6 rounded-xl font-semibold text-white transition-all transform",
                "shadow-lg hover:shadow-xl active:scale-95",
                "flex items-center justify-center gap-3",
                isConnecting && "opacity-75 cursor-not-allowed",
                isConnected 
                  ? "bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700"
                  : "bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700"
              )}
            >
              {isConnecting ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin" />
                  <span>Connecting...</span>
                </>
              ) : isConnected ? (
                <>
                  <PhoneOff className="w-5 h-5" />
                  <span>End Conversation</span>
                </>
              ) : (
                <>
                  <PhoneCall className="w-5 h-5" />
                  <span>Start Conversation</span>
                </>
              )}
            </button>
          </div>

          {/* Info Section */}
          <div className="px-6 pb-6">
            <div className="bg-blue-50 rounded-xl p-4 space-y-2">
              <h3 className="font-semibold text-blue-900 text-sm">How to use:</h3>
              <ul className="text-xs text-blue-700 space-y-1">
                <li>• Click "Start Conversation" to connect</li>
                <li>• Allow microphone access when prompted</li>
                <li>• Speak clearly in Vietnamese</li>
                <li>• Bot will help with debt collection inquiries</li>
              </ul>
            </div>
          </div>

          {/* Footer */}
          <div className="bg-gray-50 px-6 py-4 border-t border-gray-100">
            <div className="flex items-center justify-between text-xs text-gray-500">
              <div className="flex items-center gap-2">
                <Activity className="w-4 h-4" />
                <span>WebRTC: {isConnected ? 'Active' : 'Idle'}</span>
              </div>
              <span>Powered by Pipecat AI</span>
            </div>
          </div>
        </div>

        {/* Additional Info Card */}
        <div className="mt-4 bg-white/60 backdrop-blur rounded-xl p-4 text-center">
          <p className="text-xs text-gray-600">
            AWS - Amazon Web Service 
          </p>
        </div>
      </div>
    </div>
  );
}