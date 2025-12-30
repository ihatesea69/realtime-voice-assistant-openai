# bot.py - HieuNghi Voice Agent
# OpenAI-only stack: STT (Whisper) + LLM (GPT) + TTS (OpenAI)

import asyncio
import os
import json
from datetime import datetime
from aiohttp import web
from aiohttp.web import RouteTableDef
from dotenv import load_dotenv
from loguru import logger

from pipecat.audio.vad.silero import SileroVADAnalyzer, VADParams
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.pipeline.runner import PipelineRunner
from pipecat.transports.smallwebrtc.transport import SmallWebRTCTransport
from pipecat.transports.smallwebrtc.connection import SmallWebRTCConnection, IceServer
from pipecat.transports.base_transport import TransportParams
from pipecat.transcriptions.language import Language
from pipecat.processors.transcript_processor import TranscriptProcessor
from pipecat.services.openai.stt import OpenAISTTService
from pipecat.services.openai.llm import OpenAILLMService
from pipecat.services.openai.tts import OpenAITTSService
from pipecat.processors.aggregators.openai_llm_context import OpenAILLMContext
from pipecat_flows import FlowManager
from flow import create_initial_node

load_dotenv(override=True)

routes = RouteTableDef()

# WebSocket connections for transcript streaming
ws_connections = set()

# ICE servers for NAT traversal
# TURN credentials from Metered.ca (free tier)
TURN_USERNAME = os.getenv("TURN_USERNAME", "211edaaa6d320db0be95b365")
TURN_CREDENTIAL = os.getenv("TURN_CREDENTIAL", "WFn/hIuZNhCl20Iz")

ice_servers = [
    # Use TCP TURN on port 443 (HTTPS-like) to bypass aggressive firewalls/UDP blocks
    IceServer(
        urls="turn:global.relay.metered.ca:443?transport=tcp",
        username=TURN_USERNAME,
        credential=TURN_CREDENTIAL
    ),
    # Backup STUN (standard)
    IceServer(urls="stun:stun.relay.metered.ca:80"),
]

# Debug: Log ICE servers configuration
logger.info(f"🧊 ICE servers configured: {len(ice_servers)} servers")
for i, server in enumerate(ice_servers):
    logger.info(f"🧊 ICE server {i}: {server.urls}")

async def run_bot(webrtc_connection, ws_connections):
    """Run the bot pipeline with the given WebRTC connection."""
    from prompt import SYSTEM_PROMPT
    
    openai_api_key = os.getenv("OPENAI_API_KEY")
    if not openai_api_key:
        raise ValueError("OPENAI_API_KEY environment variable is required")
    
    logger.info("🚀 Starting HieuNghi Voice Agent with OpenAI stack")
    
    # OpenAI STT (Whisper)
    stt = OpenAISTTService(
        api_key=openai_api_key,
        model="whisper-1",
        language="vi"
    )
    
    # OpenAI LLM (GPT-4o-mini for cost efficiency)
    llm = OpenAILLMService(
        api_key=openai_api_key,
        model="gpt-4o-mini"
    )
    
    # OpenAI TTS
    tts = OpenAITTSService(
        api_key=openai_api_key,
        voice="nova",
        model="tts-1"
    )
    
    # Transcript processor
    transcript = TranscriptProcessor()
    
    # Session management
    session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    transcript_file = f"transcripts/conversation_{session_id}.json"
    os.makedirs("transcripts", exist_ok=True)
    
    transcript_data = {
        "session_id": session_id,
        "started_at": datetime.now().isoformat(),
        "messages": []
    }
    
    @transcript.event_handler("on_transcript_update")
    async def handle_transcript_update(processor, frame):
        """Handle transcript updates - save to file and send to UI."""
        try:
            for message in frame.messages:
                msg_dict = {
                    "role": message.role,
                    "content": message.content,
                    "timestamp": message.timestamp or datetime.now().isoformat()
                }
                transcript_data["messages"].append(msg_dict)
                with open(transcript_file, 'w', encoding='utf-8') as f:
                    json.dump(transcript_data, f, ensure_ascii=False, indent=2)
                
                for ws in list(ws_connections):
                    try:
                        await ws.send_json({
                            "type": "transcript",
                            "message": msg_dict
                        })
                    except Exception as e:
                        logger.warning(f"Failed to send transcript to WebSocket: {e}")
                        ws_connections.discard(ws)
                
                logger.info(f"📝 [{message.role}]: {message.content}")
        except Exception as e:
            logger.error(f"Error handling transcript update: {e}")
    
    # WebRTC Transport
    transport = SmallWebRTCTransport(
        webrtc_connection=webrtc_connection,
        params=TransportParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
            vad_analyzer=SileroVADAnalyzer(
                params=VADParams(
                    stop_secs=0.7,
                    start_secs=0.1,
                    min_volume=0.6
                )
            ),
        ),
    )
    
    # LLM Context
    context = OpenAILLMContext()
    context_aggregator = llm.create_context_aggregator(context)
    
    # Pipeline: STT -> LLM -> TTS
    pipeline = Pipeline([
        transport.input(),
        stt,
        transcript.user(),
        context_aggregator.user(),
        llm,
        tts,
        transport.output(),
        transcript.assistant(),
        context_aggregator.assistant(),
    ])
    
    task = PipelineTask(
        pipeline,
        params=PipelineParams(
            allow_interruptions=True,
            enable_metrics=True,
            enable_usage_metrics=True,
        )
    )
    
    # Flow Manager for conversation flow
    flow_manager = FlowManager(
        task=task,
        llm=llm,
        context_aggregator=context_aggregator,
        transport=transport,
        tts=tts
    )
    await flow_manager.initialize()
    await flow_manager.set_node("initial_node", create_initial_node())
    
    # Run pipeline
    runner = PipelineRunner()
    await runner.run(task)
    
    # Save final transcript
    transcript_data["ended_at"] = datetime.now().isoformat()
    with open(transcript_file, 'w', encoding='utf-8') as f:
        json.dump(transcript_data, f, ensure_ascii=False, indent=2)
    logger.info(f"💾 Transcript saved to {transcript_file}")


@routes.post("/offer")
async def handle_offer(request):
    """Handle WebRTC offer from client."""
    try:
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
        }
        
        body = await request.text()
        if not body or not body.strip():
            return web.json_response(
                {"error": "Request body is empty"}, 
                status=400,
                headers=headers
            )
        
        offer_data = json.loads(body)
        
        if "sdp" not in offer_data or "type" not in offer_data:
            return web.json_response(
                {"error": "Invalid offer structure. Need 'sdp' and 'type' fields"}, 
                status=400,
                headers=headers
            )
        
        logger.info("✅ Received valid WebRTC offer")
        
        webrtc_connection = SmallWebRTCConnection(ice_servers=ice_servers)
        await webrtc_connection.initialize(
            sdp=offer_data["sdp"],
            type=offer_data["type"]
        )
        
        answer = webrtc_connection.get_answer()
        
        asyncio.create_task(run_bot(webrtc_connection, ws_connections))
        
        logger.info("✅ Bot pipeline started successfully")
        return web.json_response(answer, headers=headers)
        
    except Exception as e:
        logger.error(f"❌ Error handling offer: {e}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return web.json_response(
            {"error": str(e)}, 
            status=500,
            headers={'Access-Control-Allow-Origin': '*'}
        )


@routes.options("/offer")
async def handle_offer_options(request):
    """Handle CORS preflight for /offer endpoint."""
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
    }
    return web.Response(headers=headers)


@routes.get("/ws")
async def websocket_handler(request):
    """Handle WebSocket connections for transcript streaming."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    
    ws_connections.add(ws)
    logger.info(f"WebSocket client connected. Total: {len(ws_connections)}")
    
    try:
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                data = json.loads(msg.data)
                logger.debug(f"Received WebSocket message: {data}")
            elif msg.type == web.WSMsgType.ERROR:
                logger.error(f'WebSocket error: {ws.exception()}')
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        ws_connections.discard(ws)
        logger.info(f"WebSocket client disconnected. Total: {len(ws_connections)}")
    
    return ws


@routes.get("/")
async def index(request):
    """Simple index page."""
    return web.Response(
        text="HieuNghi Voice Agent Server is running!",
        content_type="text/plain"
    )


def create_app():
    """Create the aiohttp application."""
    app = web.Application()
    
    @web.middleware
    async def cors_middleware(request, handler):
        if request.method == 'OPTIONS':
            headers = {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                'Access-Control-Max-Age': '86400',
            }
            return web.Response(headers=headers)
        
        response = await handler(request)
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        return response
    
    app.middlewares.append(cors_middleware)
    app.router.add_routes(routes)
    return app


async def main():
    """Main entry point."""
    logger.info("🚀 Starting HieuNghi Voice Agent Server...")
    
    app = create_app()
    runner = web.AppRunner(app)
    await runner.setup()
    
    # Support Docker/cloud deployment via env vars
    host = os.getenv("HOST", "localhost")
    port = int(os.getenv("PORT", 7860))
    
    site = web.TCPSite(runner, host, port)
    await site.start()
    
    logger.info(f"✅ Server started at http://{host}:{port}")
    logger.info(f"📱 WebRTC endpoint: POST http://{host}:{port}/offer")
    logger.info(f"📡 WebSocket endpoint: WS ws://{host}:{port}/ws")
    
    try:
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        logger.info("👋 Shutting down server...")
    finally:
        await runner.cleanup()


if __name__ == "__main__":
    asyncio.run(main())
