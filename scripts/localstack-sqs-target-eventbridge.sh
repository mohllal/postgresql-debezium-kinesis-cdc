#!/bin/bash

###############################################################################

AWS_REGION=us-east-1
LOCALSTACK_DUMMY_ID=000000000000
LOCALSTACK_SQS_QUEUE_ARN_BASE=arn:aws:sqs:$AWS_REGION:$LOCALSTACK_DUMMY_ID

BUSES_NAMES=("products" "customers")
RULE_NAME=forward-to-sqs
QUEUE_NAME=data-change.fifo

###############################################################################

echo "creating eventbridge rule & sqs target..."
echo "======================================"

get_eventbridge_bus_rules() {
    local bus_name=$1

    awslocal \
      events \
      list-rules \
      --event-bus-name $bus_name
}

create_eventbridge_rule() {
    local bus_name=$1
    local queue_name=$2
    local rule_name=$3

    echo "creating eventbridge rule for bus '${bus_name}' and queue '${queue_name}'..."

    awslocal \
      events \
      put-rule \
      --name $rule_name \
      --event-pattern '{"source":[{"prefix":""}]}' \
      --event-bus-name $bus_name \
      --state ENABLED \
      --output text \
      --query 'RuleArn' \
      2>/dev/null
    
   
    awslocal \
      events \
      put-targets \
      --rule "$rule_name" \
      --event-bus-name $bus_name \
      --targets "[
        {
            \"Id\": \"Target1\",
            \"Arn\": \"$LOCALSTACK_SQS_QUEUE_ARN_BASE:$queue_name\",
            \"SqsParameters\": {
                \"MessageGroupId\": \"Group1\"
            }
        }
      ]" \
      2>/dev/null

    echo "eventbridge rule for bus '${bus_name}' and queue '${queue_name}' created successfully."
}

for bus_name in "${BUSES_NAMES[@]}"; do
  create_eventbridge_rule $bus_name $QUEUE_NAME $RULE_NAME

  echo "rules currently exist in the localstack eventbridge for bus '$bus_name' are:"
  echo "$(get_eventbridge_bus_rules $bus_name)"
done


