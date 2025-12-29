import { useState, useEffect, useRef } from 'react';
import { MessageSquare, Bot, User } from 'lucide-react';
import { cn } from '../lib/utils';

interface Message {
  id: string;
  text: string;
  sender: 'user' | 'bot';
  timestamp: Date;
}

interface TranscriptViewProps {
  isConnected: boolean;
}

export function TranscriptView({ isConnected }: TranscriptViewProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const scrollRef = useRef<HTMLDivElement>(null);

  // Simulate message flow - in real app, connect to WebRTC data channel
  useEffect(() => {
    if (!isConnected) return;

    // Add welcome message
    const welcomeMsg: Message = {
      id: '1',
      text: 'Chào anh/chị, cảm ơn anh/chị đã liên hệ đến Công ty Mua Bán Nợ ABC. Em là Nghiêm, em có thể hỗ trợ gì cho anh/chị ạ?',
      sender: 'bot',
      timestamp: new Date()
    };
    setMessages([welcomeMsg]);
  }, [isConnected]);

  // Auto-scroll to bottom
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  if (!isConnected) {
    return (
      <div className="h-full flex items-center justify-center p-8">
        <div className="text-center space-y-2">
          <MessageSquare className="w-12 h-12 mx-auto text-gray-300" />
          <p className="text-gray-500 text-sm">
            Connect to start conversation
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-gray-200 bg-gray-50">
        <h3 className="font-semibold text-gray-900 flex items-center gap-2">
          <MessageSquare className="w-5 h-5" />
          Conversation Transcript
        </h3>
      </div>

      {/* Messages */}
      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto p-4 space-y-4"
      >
        {messages.map((message) => (
          <div
            key={message.id}
            className={cn(
              "flex gap-3",
              message.sender === 'user' ? "flex-row-reverse" : "flex-row"
            )}
          >
            {/* Avatar */}
            <div className={cn(
              "w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0",
              message.sender === 'user' 
                ? "bg-blue-100 text-blue-600"
                : "bg-purple-100 text-purple-600"
            )}>
              {message.sender === 'user' ? (
                <User className="w-4 h-4" />
              ) : (
                <Bot className="w-4 h-4" />
              )}
            </div>

            {/* Message bubble */}
            <div className={cn(
              "max-w-[70%] px-4 py-2 rounded-2xl",
              message.sender === 'user'
                ? "bg-blue-500 text-white rounded-tr-sm"
                : "bg-gray-100 text-gray-900 rounded-tl-sm"
            )}>
              <p className="text-sm">{message.text}</p>
              <p className={cn(
                "text-xs mt-1",
                message.sender === 'user' 
                  ? "text-blue-100"
                  : "text-gray-500"
              )}>
                {message.timestamp.toLocaleTimeString()}
              </p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}