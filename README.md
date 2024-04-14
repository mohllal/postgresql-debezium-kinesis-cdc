# Change Data Capture using Debezium

This repo demonstrates the implementation of a Change Data Capture (CDC) pipeline.

This repository contains the complete working code for the Medium article: [Change Data Capture (CDC) with PostgreSQL, Debezium, Kinesis, and EventBridge](https://medium.com/@mohllal/change-data-capture-cdc-with-debezium-kinesis-and-eventbridge-10eb5a996788).

I am using:

1. PostgreSQL database as the source.
2. Debezium to capture data changes.
3. AWS Kinesis data stream as the destination.
4. AWS Lambda to transform events via event source mapping (ESM).
5. AWS EventBridge event bus as the event storage.
6. AWS SQS queue as the final target for bus events.

-----

## Components

### PostgreSQL database

The source database consists of four tables: `products`, `stock`, `customers`, and `orders`. You can find the SQL script to initialize these tables [here](./scripts/inventory.sql).

To use Debezium with PostgreSQL, [it's necessary to enable logical decoding with the write-ahead log](https://debezium.io/documentation/reference/stable/postgres-plugins.html) and using either the `decoderbufs` logical decoding plugin or the `pgoutput` plugin, which is used by default.

### Kinesis stream

The Kinesis streams serve as the destination datastore for the data change events. Each table requires its own Kinesis stream, which must be pre-created because Debezium does not manage stream creation.

Debezium is expecting streams to be named as follows `prefix.schema.table` and to customize the mapping between streams and tables, a custom [StreamNameMapper](https://debezium.io/documentation/reference/operations/debezium-server.html#kinesis-ext-stream-name-mapper) needs to be implemented and thus Debezium needs to run in embedded mode; Here is [an example](https://github.com/debezium/debezium-examples/tree/main/debezium-server-name-mapper) of implementing a custom topic naming policy.

### Debezium server

This acts as the core engine, continuously monitoring the PostgreSQL database for changes (inserts, updates, deletes) using the [PostgreSQL source connector](https://debezium.io/documentation/reference/stable/connectors/postgresql.html). It then transmits these change events to a Kinesis data stream using the [Kinesis sink connector](https://debezium.io/documentation/reference/stable/operations/debezium-server.html#_amazon_kinesis).

#### Debezium configurations

The [application.properties](./configs/debezium/application.properties) file hosts the source and sink configurations.

I have customized the settings to capture data change events exclusively for the `products` and `customers` tables, while opting not to synchronize data for the `stock` and `orders` table.

Furthermore, to showcase the ability to synchronize only specific columns from a table, I have chosen to exclude the `products.created_at` and `customers.created_at` columns from the capture process.

```properties
debezium.source.table.include.list=inventory.products,inventory.customers
debezium.source.column.exculde.list=inventory.products.created_at,inventory.customers.created_at
```

#### Example data change event

Here is an example of Debezium data change event that represents an insert operation

```json
{
   "schema": { ... },
   "payload": {
      "before":null,
      "after": {
         "id":101,
         "name":"scooter",
         "description":"Small 2-wheel scooter",
         "created_at":1712233827622718
      },
      "source": {
         "version":"2.5.3.Final",
         "connector":"postgresql",
         "name":"kinesis",
         "ts_ms":1712233847439,
         "snapshot":"first",
         "db":"inventory_db",
         "sequence":"[null,\"23105272\"]",
         "schema":"inventory",
         "table":"products",
         "txId":504,
         "lsn":23105272,
         "xmin":null
      },
      "op":"r",
      "ts_ms":1712233847515,
      "transaction":null
   }
}
```

### EventBridge event bus

Using EventBridge Pipes simplifies [connecting a Kinesis stream to an EventBridge bus](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-kinesis.html) by ingesting, and possibly transforming if needed, events before publishing to the target EventBridge bus.

However, LocalStack's community edition [lacks support for EventBridge Pipes](https://docs.localstack.cloud/references/coverage/coverage_pipes/). As an alternative, to achieve similar functionality of publishing events to an EventBridge bus, [a Lambda function can be set up with a Kinesis stream as an event source mapping](https://docs.aws.amazon.com/lambda/latest/dg/with-kinesis.html).

### Lambda event-source mapping (ESM)

Lambda event source mapping is set up to proccess Kinesis stream records, triggering a Lambda function to forward events to the EventBridge bus.

For the event schema of Kinesis stream records, refer to the documentation [here](https://docs.aws.amazon.com/lambda/latest/dg/with-kinesis.html#services-kinesis-event-example).

```python
try:
   #...
   for record in event["Records"]:
      encoded_record_data = record["kinesis"]["data"]
      decoded_record_data = base64.b64decode(encoded_record_data).decode("utf-8")
      record_data = json.loads(decoded_record_data)

      # Example event source ARN: "arn:aws:kinesis:us-east-1:XXXX:stream/stream-name"
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

   response = eventbridge.put_events(Entries=event_entries)
   #...
except Exception as e:
   logger.error(e, exc_info=True)
   raise e
```

### SQS queue

The final destination set to receive all events from the event buses. Here's the EventBridge rule used for capturing all events from the bus.

```shell
awslocal \
    ...
    events \
    put-rule \
    --event-pattern '{"source":[{"prefix":""}]}' \
   ...
```

### SQS consumer

A Python consumer that continuously polls the SQS queue and logs the received messages.

```python
#...
while True:
    response = sqs.receive_message(QueueUrl=queue_url)

    for sqs_message in response.get("Messages", []):
        message = SQSMessage.model_validate(sqs_message)

        bus_event = EventBridgeEvent.model_validate_json(message.body)
        logger.info("Received event detail-type: %s, source: %s", bus_event.detail_type, bus_event.source)

        change_data_event = DebeziumEvent.model_validate(bus_event.detail)
        logger.info("Message id '%s' - Event 'before': %s", message.id, change_data_event.payload.before)
        logger.info("Message id '%s' - Event 'after': %s", message.id, change_data_event.payload.after)
        
        _delete_message(message.receipt_handle)
        logger.info("Message with id '%s' deleted successfully.", message.id)
#...
```

Below are sample logs from the SQS consumer container, showcasing a change data event for an insert operation on the products table.

```plaintext
2024-04-13 23:13:56 21:13:56.908 [main] INFO consumer - Received event detail-type: ProductDataChangeEvent, source: kinesis.inventory.products
2024-04-13 23:13:56 21:13:56.908 [main] INFO consumer - Data change event - before: None
2024-04-13 23:13:56 21:13:56.909 [main] INFO consumer - Data change event - after: {'id': 101, 'name': 'scooter', 'description': 'Small 2-wheel scooter', 'created_at': 1712934636990657, 'modified_at': 1712934636990657}
```

-----

## Usage

All services can be run using Docker Compose

1- Start the Docker Compose services by running:

```shell
docker-compose up
```

2- Monitor the logs of the `sqs-consumer` container to observe change data events triggered by insertions, updates, and deletions in the database.

3- To stop the Docker Compose services, execute:

```shell
docker-compose down
```

All Docker volume mounts for all services will be located in the `.docker` directory.
