import os
import json
import logging
import base64
from datetime import datetime

import boto3


logger = logging.getLogger()
logger.setLevel(logging.INFO)

stream_event_detail_type_mapping = {
    "kinesis.inventory.products": "ProductDataChangeEvent",
    "kinesis.inventory.customers": "CustomerDataChangeEvent",
}

stream_event_bus_mapping = {
    "kinesis.inventory.products": os.environ.get("PRODUCTS_EVENT_BUS_NAME"),
    "kinesis.inventory.customers": os.environ.get("CUSTOMERS_EVENT_BUS_NAME"),
}


def handler(event, context):
    """
    Lambda function to handle data ingestion from a dedicated Kinesis consumer
    and publish events to an EventBridge event bus.

    Example event: https://docs.aws.amazon.com/lambda/latest/dg/with-kinesis.html#services-kinesis-event-example

    :param event: The event data received from the Kinesis stream.
    :type event: dict
    :param context: The runtime information of the Lambda function.
    :type context: dict
    :raises Exception: If there is an error during execution.
    :return: A response indicating the status of the event publishing.
    :rtype: dict
    """
    try:
        logger.info("Received Lambda event: %s", event)
        logger.info("Received Lambda context: %s", context)

        eventbridge = boto3.client("events")

        event_entries = []
        for record in event["Records"]:
            encoded_record_data = record["kinesis"]["data"]
            decoded_record_data = base64.b64decode(encoded_record_data).decode("utf-8")
            record_data = json.loads(decoded_record_data)

            # Example event source ARN: "arn:aws:kinesis:us-east-2:XXXX:stream/stream-name"
            stream_name = record["eventSourceARN"].split("/")[1]

            detail_type = stream_event_detail_type_mapping[stream_name]
            bus_name = stream_event_bus_mapping[stream_name]

            transformed_event = _transform_event(record_data)

            event_entry = {
                "Source": stream_name,
                "DetailType": detail_type,
                "Detail": json.dumps(transformed_event),
                "EventBusName": bus_name,
                "Time": str(datetime.now()),
            }
            event_entries.append(event_entry)

        logger.info("Putting events to EventBridge bus: %s", event_entries[0]["EventBusName"])
        response = eventbridge.put_events(Entries=event_entries)
        logger.info("Received EventBridge response: %s", response)

        if response["FailedEntryCount"] > 0:
            failed_entries = [
                entry for entry in response["Entries"] if "ErrorCode" in entry
            ]
            error_message = (
                f"Failed to put events. Entries with errors: {failed_entries}"
            )
            raise Exception(error_message)
    except Exception as e:
        logger.error(e, exc_info=True)
        raise e


def _transform_event(event):
    """
    Transforms the event data before publishing it to the EventBridge bus.

    :param event: The event data to transform.
    :type event: dict
    :return: The transformed event data.
    :rtype: dict
    """

    # event transformation logic here...

    return event
