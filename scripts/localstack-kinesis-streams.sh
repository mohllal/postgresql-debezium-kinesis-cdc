#!/bin/bash

###############################################################################

STREAMS_NAMES=("kinesis.inventory.products" "kinesis.inventory.customers")

###############################################################################

echo "creating kinesis streams..."
echo "======================================"

get_all_kinesis_streams() {
    awslocal \
      kinesis \
      list-streams
}

create_kinesis_stream() {
    local stream_name=$1

    if ! kinesis_stream_exists $stream_name; then
      echo "stream '${stream_name}' does not exist, creating..."

      awslocal \
        kinesis \
        create-stream \
        --shard-count 1 \
        --stream-name $stream_name \
        >/dev/null 2>&1

      echo "stream '${stream_name}' created successfully."
    else
      echo "stream '${stream_name}' already exists."
    fi
}

kinesis_stream_exists() {
    local stream_name=$1

    local stream_description=$(awslocal \
      kinesis \
      describe-stream \
      --stream-name ${stream_name} \
      2>/dev/null
    )

    if [ -n "$stream_description" ]; then
      return 0
    else
      return 1
    fi
}

for stream_name in "${STREAMS_NAMES[@]}"; do
    create_kinesis_stream $stream_name
done

echo "streams currently exist in the localstack kinesis are:"
echo "$(get_all_kinesis_streams)"
