#!/bin/bash

###############################################################################

BUSES_NAMES=("products" "customers")

###############################################################################

echo "creating event buses..."
echo "======================================"

get_all_event_buses() {
    awslocal \
      events \
      list-event-buses
}

create_event_bus() {
    local bus_name=$1

    if ! event_bus_exists $bus_name; then
      echo "bus '${bus_name}' does not exist, creating..."

      awslocal \
        events \
        create-event-bus \
        --name $bus_name \
        >/dev/null 2>&1

      echo "bus '${bus_name}' created successfully."
    else
      echo "bus '${bus_name}' already exists."
    fi
}

event_bus_exists() {
    local bus_name=$1

    local bus_description=$(awslocal \
      events \
      describe-event-bus \
      --name ${bus_name} \
      2>/dev/null
    )

    if [ -n "$bus_description" ]; then
      return 0
    else
      return 1
    fi
}

for bus_name in "${BUSES_NAMES[@]}"; do
    create_event_bus $bus_name
done

echo "buses currently exist in the localstack eventbridge are:"
echo "$(get_all_event_buses)"
