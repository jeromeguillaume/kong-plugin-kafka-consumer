local typedefs = require "kong.db.schema.typedefs"

return {
  name = "kafka-consumer",
  fields = {
    {
      -- this plugin will only be applied to Services or Routes
      consumer = typedefs.no_consumer
    },
    {
      -- this plugin will only run within Nginx HTTP module
      protocols = typedefs.protocols_http
    },
    {
      config = {
        type = "record",
        fields = {
          { kafka_broker_host  = typedefs.host ({ required = true, default = "kafka-kafka-1" }) },
          { kafka_broker_port  = typedefs.port ({ required = true, default = 9092 }) },
          { kafka_broker_topic = { type = "string", required = true, default = "test" } },
          { kafka_offset_timestamp = { type = "string", required = true, default = "Max", one_of = { "First", "Max" },}},
        },
      },
    },
  },
  entity_checks = {
    -- Describe your plugin's entity validation rules
  },
}
