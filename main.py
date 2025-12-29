#!/usr/bin/env python
"""
HieuNghi Voice Agent - Customer Support Demo
WebRTC-based voice assistant using OpenAI stack (STT/LLM/TTS)
"""

import sys
import os

# Add src to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

# Import and run the bot application
from src.bot import main
import asyncio

if __name__ == "__main__":
    asyncio.run(main())