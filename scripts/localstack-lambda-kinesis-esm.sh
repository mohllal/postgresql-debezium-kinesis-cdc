#!/bin/bash

###############################################################################

AWS_REGION=us-east-1
LOCALSTACK_DUMMY_ID=000000000000
LOCALSTACK_KINESIS_STREAM_ARN_BASE=arn:aws:kinesis:$AWS_REGION:$LOCALSTACK_DUMMY_ID:stream

STREAMS_NAMES=("kinesis.inventory.products" "kinesis.inventory.customers")
FUNCTION_NAME=kinesis-esm

###############################################################################

echo "creating lambda event source mappings for kinesis streams..."
echo "======================================"

get_all_event_source_mappings() {
    awslocal \
      lambda \
      list-event-source-mappings
}

create_event_source_mapping() {
    local lambda_function_name=$1
    local kinesis_stream_arn=$2

    if ! event_source_mapping_exists $lambda_function_name $kinesis_stream_arn; then
        echo "event source mapping for lambda '${lambda_function_name}' and stream ARN '${kinesis_stream_arn}' does not exist, creating..."

        awslocal \
          lambda \
          create-event-source-mapping \
          --function-name $lambda_function_name \
          --event-source-arn $kinesis_stream_arn \
          --starting-position TRIM_HORIZON \
          --maximum-retry-attempts -1 \
          --batch-size 10 \
          >/dev/null 2>&1

        echo "event source mapping for lambda '${lambda_function_name}' and stream ARN '${kinesis_stream_arn}' created successfully."
    else
        echo "event source mapping for lambda '${lambda_function_name}' and stream ARN '${kinesis_stream_arn}' already exists."
    fi
}

event_source_mapping_exists() {
    local lambda_function_name=$1
    local kinesis_stream_arn=$2

    local event_source_mapping_description=$(awslocal \
      lambda \
      list-event-source-mappings \
      --function-name $lambda_function_name \
      --query "EventSourceMappings[?EventSourceArn=='$kinesis_stream_arn']" \
      --output text \
      2>/dev/null
    )

    if [ -n "$event_source_mapping_description" ]; then
      return 0
    else
      return 1
    fi
}

for stream_name in "${STREAMS_NAMES[@]}"; do
    create_event_source_mapping $FUNCTION_NAME "${LOCALSTACK_KINESIS_STREAM_ARN_BASE}/${stream_name}"
done

echo "event source mappings currently exist in the localstack lambda are:"
echo "$(get_all_event_source_mappings)"
