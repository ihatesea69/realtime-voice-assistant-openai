# flow.py - HieuNghi Voice Agent Conversation Flow

import sys
import json
import os
from datetime import datetime
from typing import Optional
from dataclasses import dataclass
from dotenv import load_dotenv
from loguru import logger

from pipecat.frames.frames import EndFrame
from pipecat_flows import FlowArgs, FlowResult, FlowsFunctionSchema, NodeConfig, FlowManager
from prompt import SYSTEM_PROMPT, TASK_PROMPT, END_PROMPT

load_dotenv(override=True)

logger.remove(0)
logger.add(sys.stderr, level="DEBUG")


@dataclass
class CustomerInfoResult(FlowResult):
    """Result from collecting customer information."""
    name: str = ""
    phone: str = ""
    inquiry_type: str = ""
    notes: str = ""
    
    def __str__(self):
        return f"name={self.name}, phone={self.phone}, type={self.inquiry_type}"


async def transition_callback(args, result, flow_manager):
    """Transition logic after collect_customer_info."""
    if flow_manager.state.get("end_conversation"):
        logger.info("✅ Ending conversation")
        await flow_manager.task.queue_frames([EndFrame()])
        return
    
    # Stay in initial node for continued conversation
    logger.info("↩️ Continuing conversation")
    node = create_initial_node()
    node["role_messages"] = []  # Avoid re-adding system prompt
    await flow_manager.set_node("initial_node", node)


async def collect_customer_info(args: FlowArgs, flow_manager: FlowManager) -> CustomerInfoResult:
    """Collect customer information and log the interaction."""
    name = args.get("customer_name", "")
    phone = args.get("phone_number", "")
    inquiry_type = args.get("inquiry_type", "general")
    notes = args.get("notes", "")
    end_call = args.get("end_call", False)
    
    logger.info(f"📋 Customer info: name={name}, phone={phone}, type={inquiry_type}")
    
    # Save to output
    result_data = {
        "name": name,
        "phone": phone,
        "inquiry_type": inquiry_type,
        "notes": notes,
        "timestamp": datetime.now().isoformat()
    }
    
    try:
        output_path = os.path.join(os.path.dirname(__file__), 'output', 'result.json')
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result_data, f, ensure_ascii=False, indent=2)
        logger.info(f"✅ Saved customer info to {output_path}")
    except Exception as e:
        logger.error(f"❌ Failed to save result: {e}")
    
    flow_manager.state["customer_info"] = result_data
    
    if end_call:
        flow_manager.state["end_conversation"] = True
    
    return CustomerInfoResult(
        name=name,
        phone=phone,
        inquiry_type=inquiry_type,
        notes=notes
    )


def create_initial_node() -> NodeConfig:
    """Create the initial conversation node."""
    return {
        "name": "initial_node",
        "role_messages": [
            {
                "role": "system",
                "content": SYSTEM_PROMPT
            }
        ],
        "task_messages": [
            {
                "role": "user",
                "content": TASK_PROMPT
            }
        ],
        "functions": [
            FlowsFunctionSchema(
                name="collect_customer_info",
                description="Thu thập thông tin khách hàng hoặc kết thúc cuộc hội thoại",
                properties={
                    "customer_name": {
                        "type": "string",
                        "description": "Tên khách hàng"
                    },
                    "phone_number": {
                        "type": "string",
                        "description": "Số điện thoại khách hàng"
                    },
                    "inquiry_type": {
                        "type": "string",
                        "enum": ["product", "order", "technical", "complaint", "general"],
                        "description": "Loại yêu cầu: product (sản phẩm), order (đơn hàng), technical (kỹ thuật), complaint (khiếu nại), general (chung)"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Ghi chú về yêu cầu của khách"
                    },
                    "end_call": {
                        "type": "boolean",
                        "description": "True nếu khách muốn kết thúc cuộc gọi"
                    }
                },
                required=[],
                handler=collect_customer_info,
                transition_callback=transition_callback,
            )
        ]
    }


def create_end_node() -> NodeConfig:
    """Create the end node."""
    return {
        "name": "end",
        "task_messages": [],
        "functions": [],
        "post_actions": [{"type": "end_conversation"}]
    }
