# kafka-consumer: Kong custom plugin
This is a custom plugin for Kong to consume messages from Kafka topics.
It uses the Lua library [lua-resty-kafka](https://github.com/doujiang24/lua-resty-kafka) version 0.20 which is a Kafka client driver for the ngx_lua nginx module. The [lua-resty-kafka](https://github.com/doujiang24/lua-resty-kafka), version already embedded in Kong Gateway (for [kafka-log](https://docs.konghq.com/hub/kong-inc/kafka-log/#implementation-details) and [kafka-upstream plugins](https://docs.konghq.com/hub/kong-inc/kafka-upstream/#implementation-details)), is 0.14 so we update the Lua library.

## How deploy the plugin in Kong and Kafka environment?
1) Git clone this repository
2) Export the license key for Kong Enterprise Gateway to a variable. Please adapt the content in regards of your license:
```
 export KONG_LICENSE_DATA='{"license":{"payload":...}}'
```
3) Deploy Kong Gateway v3.1, Kafka and Zookeeper with this command:
```
docker-compose up -d
```
4) Check that the Kong Manager is working correctly [http://localhost:8002](http://localhost:8002)
5) Check that Kafka is working correctly
- Produce a message in the ```test``` Kafka topic, open a terminal (#1):
```
docker exec -it kafka-kafka-1 bash
kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test
```
Type ```kong1``` and press Enter

- Consume the ```kong1``` message from the ```test``` Kafka topic, open a new terminal (#2):
```
docker exec -it kafka-kafka-1 bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning
```
Wait a few seconds and you will see ```kong1``` message. 
Repeat this by switching to terminal #1 and type the messages  ```kong2``` and ```kong3```

## How test the kafka-consumer plugin in Kong?
1) Create a route with the name ```kafkaConsumer``` and path ```/kafkaConsumer```. There is no Service (linked with the route) because the route consumes the messages from the kafka topic and returns the messages content
2) Install the ```kafka-consumer``` plugin to the route ```kafkaConsumer```, no need to change the default parameters
3) Test the route:
```
http :8000/kafkaConsumer
```
The plugin retrives the **last message** from the topic and the expected result is:
```
HTTP/1.1 200 OK
...
Server: kong/3.1.1.3-enterprise-edition
X-Kong-Response-Latency: 423
```
```json
{
    "Kafka Topic Name": "test"
    "Kafka Topic Message(s)": {
        {
            "offset": 2,
            "value": "kong3"
        }
    }
}
```
3) Test the route with offset equals to ```First```:
- Open the ```kafkaConsumer```, change ```kafka_offset_timestamp``` to ```First``` and Save
- Test the route:
```
http :8000/kafkaConsumer
```
The plugin retrives the **all messages** from the topic and the expected result is:
```
HTTP/1.1 200 OK
...
Server: kong/3.1.1.3-enterprise-edition
X-Kong-Response-Latency: 50
```
```json
{
    "Kafka Topic Name": "test"
    "Kafka Topic Message(s)": {
        {
            "offset": 0,
            "value": "kong1"
        },
        {
            "offset": 1,
            "value": "kong2"
        },
        {
            "offset": 2,
            "value": "kong3"
        }
    }
}
```
## Default parameters of ```kafka-consumer``` plugin
![Alt text](/images/KongManager-plugin-conf.png?raw=true "Kong - Manager")