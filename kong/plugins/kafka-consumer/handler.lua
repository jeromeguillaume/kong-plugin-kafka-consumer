-- handler.lua

local kafkaConsumer = {
    PRIORITY = 1,
    VERSION = "0.1",
  }

---------------------------------------------------
-- Call back function for call of 'kong.cache:get'
---------------------------------------------------
local function to_be_cached (arg) 
    return arg
end
------------------------------------------------------
-- Executed for every request from a client and 
-- before it is being proxied to the upstream service
------------------------------------------------------
function kafkaConsumer:access(plugin_conf)
    kong.log.notice("kafkaConsumer *** BEGIN ***")
    
    local error = false
    local partitionId = 0
    local cjson = require "cjson"
    local client = require "resty.kafka.client"
    local bconsumer = require "resty.kafka.basic-consumer"
    local protocol_consumer = require "resty.kafka.protocol.consumer"

    -- Preparer the list of Brokers
    local broker_list = {
        {
            host = plugin_conf.kafka_broker_host,
            port = plugin_conf.kafka_broker_port
        },
    }

    local cli = client:new(broker_list)

    -- Get the Partition ID from Kafka
    local brokers, partitions = cli:fetch_metadata(plugin_conf.kafka_broker_topic)
    if not brokers then
        kong.log.err("fetch_metadata failed, err:", partitions)
        error = true
    else
        kong.log.notice("brokers: ".. cjson.encode(brokers) .. "; partitions: " .. cjson.encode(partitions))
        kong.log.notice("partitions[0].id: ", partitions[0].id)
        partitionId = partitions[0].id
    end

    -- Get the offset from the Plugin configuration
    local offsetTimestamp = protocol_consumer.LIST_OFFSET_TIMESTAMP_MAX
    if plugin_conf.kafka_offset_timestamp == 'First' then
        offsetTimestamp = protocol_consumer.LIST_OFFSET_TIMESTAMP_FIRST
    elseif plugin_conf.kafka_offset_timestamp == 'Max' then
        offsetTimestamp = protocol_consumer.LIST_OFFSET_TIMESTAMP_MAX
    end
    -- Get the message Offset from a Topic on the kafka partition ID (retrieved above)
    local cli2
    local offset
    local err
    if error == false then
        
        cli2 = bconsumer:new(broker_list)
        
        offset, err = cli2:list_offset(plugin_conf.kafka_broker_topic, partitionId, offsetTimestamp)
        if err then
            kong.log.err("list_offset failed, err:", err)
            error = true
        end
    end

    -- The offset is a Long Long (LL) integer (64 bits)
    -- We remove the 'LL' suffix because we have to use the 'tonumber' function (which doens't understand 'LL')
    local result
    local offset64
    if error == false then
        kong.log.notice("offset: " .. offset)
        offset64 = offset:gsub("LL","")
        kong.log.notice("offset without LL: " .. tonumber(offset64))
        result, err = cli2:fetch(plugin_conf.kafka_broker_topic, 0, tonumber(offset64))
        if err then
            kong.log.err("fetch failed, err:", err)
            error = true
        end
    end
    
    -- Get all messages from the topic
    -- If we got the offset by using LIST_OFFSET_TIMESTAMP_MAX   there is only 1 message in 'record'
    -- If we got the offset by using LIST_OFFSET_TIMESTAMP_FIRST there are all messages  in 'record'
    local message = ''
    if error == false then 
        message = '{\
    \"Kafka Topic Name\": \"' .. plugin_conf.kafka_broker_topic  .. '\"\
    \"Kafka Topic Message(s)\": {\
        '
        kong.log.notice("Before loop")
        
        for i, record in pairs(result.records) do
            kong.log.notice("i: " .. i)
            if i >1 then
                message = message .. 
        ',\
        '
            end
            message = message .. 
        '{\
            \"offset\": ' .. tonumber(offset64) + i - 1 .. ',\
            \"value\": \"' .. result.records[i].value .. '\"\
        }'
        end
        message = message ..  '\
    }\
}'
    end

    -- If we succeeded getting Message(s) from the Kafka topic
    if error == false then
        return kong.response.exit(200, message, {["Content-Type"] = "application/json"})
    -- We failed to get message(s) from the Kafka topic
    else
        return kong.response.exit(500, "{\
        \"Error Code\": " .. 500 .. ",\
        \"Error Message\": \"Unable to get message from Kafka topic\"\
        }",
        {
        ["Content-Type"] = "application/json"
        }
      )
    end

    kong.log.notice("kafkaConsumer *** END ***")
end

return kafkaConsumer
