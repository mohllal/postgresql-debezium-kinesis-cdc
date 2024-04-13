from typing import Optional

from pydantic import BaseModel, Field


class DebeziumSource(BaseModel):
    version: str
    connector: str
    name: str
    ts_ms: int
    snapshot: Optional[str]
    db: str
    source_schema: str = Field(..., alias="schema")
    table: str
    txId: Optional[int]
    lsn: Optional[int]
    xmin: Optional[int]


class DebeziumPayload(BaseModel):
    before: Optional[dict]
    after: Optional[dict]
    source: DebeziumSource
    op: str
    ts_ms: int
    transaction: Optional[str]


class DebeziumEvent(BaseModel):
    event_schema: dict = Field(..., alias="schema")
    payload: DebeziumPayload


class EventBridgeEvent(BaseModel):
    version: str
    id: str
    detail_type: str = Field(..., alias="detail-type")
    source: str
    account: str
    time: str
    region: str
    resources: list
    detail: DebeziumEvent


class SQSMessage(BaseModel):
    id: str = Field(..., alias="MessageId")
    receipt_handle: str = Field(..., alias="ReceiptHandle")
    body: str = Field(..., alias="Body")


__all__ = ["SQSMessage", "EventBridgeEvent", "DebeziumEvent", "DebeziumPayload", "DebeziumSource"]
