#!/bin/bash

###############################################################################

AWS_REGION=us-east-1
LOCALSTACK_DUMMY_ID=000000000000
LOCALSTACK_SQS_QUEUE_ARN_BASE=arn:aws:sqs:$AWS_REGION:$LOCALSTACK_DUMMY_ID
QUEUE_NAME=data-change.fifo
DLQ_QUEUE_NAME=data-change-dlq.fifo

###############################################################################

echo "creating sqs queues..."
echo "======================================"

get_all_sqs_queues() {
    awslocal \
      sqs \
      list-queues
}

create_sqs_queue() {
    local queue_name=$1

    if ! sqs_queue_exists $queue_name; then
      echo "queue '${queue_name}' does not exist, creating..."

      awslocal \
        sqs \
        create-queue \
        --queue-name $queue_name \
        --attributes FifoQueue=true,ContentBasedDeduplication=true \
        >/dev/null 2>&1

      echo "queue '${queue_name}' created successfully."
    else
      echo "queue '${queue_name}' already exists."
    fi
}

get_queue_url() {
    local queue_name=$1

    awslocal \
      sqs \
      get-queue-url \
      --queue-name $queue_name \
      --output text
}

sqs_queue_exists() {
    local queue_name=$1

    local queue_url=$(get_queue_url $queue_name)

    if [ -n "$queue_url" ]; then
      return 0
    else
      return 1
    fi
}

attach_dlq_to_queue() {
    local queue_name=$1
    local dlq_queue_name=$2
    
    local queue_url=$(get_queue_url $queue_name)
    local dlq_queue_url=$(get_queue_url $dlq_queue_name)

    local dlq_queue_arn="${LOCALSTACK_SQS_QUEUE_ARN_BASE}:${dlq_queue_name}"

    awslocal \
      sqs set-queue-attributes \
      --queue-url $queue_url \
      --attributes '{
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"$dlq_queue_arn\",\"maxReceiveCount\":\"10\"}"
      }'

    echo "Dead-letter queue '$dlq_queue_name' attached to queue '$queue_name' with maxReceiveCount=10."
}

create_sqs_queue $QUEUE_NAME
create_sqs_queue $DLQ_QUEUE_NAME

attach_dlq_to_queue $QUEUE_NAME $DLQ_QUEUE_NAME

echo "queues currently exist in the localstack sqs are:"
echo "$(get_all_sqs_queues)"
