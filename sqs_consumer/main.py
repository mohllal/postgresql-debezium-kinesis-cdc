import os
import boto3
import logging

from models import DebeziumEvent, EventBridgeEvent, SQSMessage

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

handler = logging.StreamHandler()
formatter = logging.Formatter(
    fmt="%(asctime)s.%(msecs)03d [%(module)s] %(levelname)s %(funcName)s - %(message)s",
    datefmt="%H:%M:%S"
)
handler.setFormatter(formatter)
logger.addHandler(handler)

sqs = boto3.client('sqs', endpoint_url=os.getenv("AWS_ENDPOINT_URL"))

queue_url = os.environ.get("SQS_QUEUE_URL")


def consumer():
    """
    Continuously poll the SQS queue for messages.
    When a message is received, log it and delete it from the queue.
    :return: None
    :rtype: None
    """

    logger.info("Polling SQS queue '%s' ...", queue_url)

    while True:
        response = sqs.receive_message(
            QueueUrl=queue_url,
            AttributeNames=["All"],
            MessageAttributeNames=["All"],
            VisibilityTimeout=10,
            WaitTimeSeconds=5
        )

        for sqs_message in response.get("Messages", []):
            message = SQSMessage.model_validate(sqs_message)

            bus_event = EventBridgeEvent.model_validate_json(message.body)
            logger.info("Received event detail-type: %s, source: %s", bus_event.detail_type, bus_event.source)

            change_data_event = DebeziumEvent.model_validate(bus_event.detail)
            logger.info("Message id '%s' - Event 'before': %s", message.id, change_data_event.payload.before)
            logger.info("Message id '%s' - Event 'after': %s", message.id, change_data_event.payload.after)

            _delete_message(message.receipt_handle)
            logger.info("Message with id '%s' deleted successfully.", message.id)


def _delete_message(receipt_handle: str):
    """
    Delete a message from the queue

    :param receipt_handle: The receipt handle of the message to delete
    :type receipt_handle: str
    :return: None
    :rtype: None
    :raises: SQS.Client.exceptions.ReceiptHandleIsInvalid if the receipt handle is invalid
    """

    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=receipt_handle
    )


if __name__ == "__main__":
    consumer()
