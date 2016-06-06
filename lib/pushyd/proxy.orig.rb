#!/usr/bin/env ruby
require 'terminal-table'
require 'hashie'
require 'securerandom'

# Log output
def header rule, sign, topic, route
  puts
  puts SEPARATOR
  puts sprintf "%s | %-20s %1s %-10s | %s",
    DateTime.now.iso8601, rule, sign, topic, route
  puts SEPARATOR
end


def extract ctype, payload, fields = []
  # Force encoding (pftop...)
  utf8payload = payload.force_encoding('UTF-8')

  # Parse payload if content-type provided
  case ctype
    when "application/json"
      # if fields = rule[:payload_extract]
      #   data = payload_extract(payload, fields)
      #   data_source = "extract #{fields.inspect} #{data.keys.count}k"
      return JSON.parse utf8payload

    when "text/plain"
      return utf8payload.to_s

    else
      return utf8payload

  end

  # Handle body parse errors
  rescue Encoding::UndefinedConversionError => e
    puts "\t JSON PARSE ERROR: #{e.inspect}"
    return {}

end


# def payload_extract payload, fields = []
#     new_payload = payload.force_encoding('UTF-8')
#     parsed = JSON.parse new_payload

#   rescue Encoding::UndefinedConversionError => e
#     puts "\t JSON PARSE ERROR: #{e.inspect}"
#     return {}

#   else
#     return parsed
# end



# def handle_message rule_name, rule, delivery_info, metadata, payload
#   # Prepare data
#   msg_topic = delivery_info.exchange
#   msg_rkey = delivery_info.routing_key.force_encoding('UTF-8')
#   msg_headers = metadata.headers || {}

#   # Extract fields
#   data = extract metadata.content_type, payload, rule

#   # Announce match
#   header rule_name, "<", msg_topic, msg_rkey

#   # Build notification payload
#   body = {
#     # received: msg_topic,
#     exchange: msg_topic,
#     route: msg_rkey,
#     #headers: msg_headers,
#     sent_at: msg_headers['sent_at'],
#     sent_by: msg_headers['sent_by'],
#     data: data,
#     }
#   pretty_body = JSON.pretty_generate(body)

#   # Dump body data
#   puts "RULE: #{rule.inspect}"
#   puts "APP-ID: #{metadata.app_id}"
#   puts "CONTENT-TYPE: #{metadata.content_type}"
#   puts pretty_body

#   # Propagate data if needed
#   propagate rule[:relay], pretty_body
# end

def topic channel, name
  @topics ||= {}
  @topics[name] ||= channel.topic(name, durable: true, persistent: true)
end

def shout exchange, keys, body = {}
  # Add timestamp
  headers = {
    sent_at: DateTime.now.iso8601,
    sent_by: PROXY_IDENT
    }
  exchange_name = exchange.name

  # Prepare key and data
  routing_key = keys.unshift(exchange_name).join('.')
  # payload = data

  # Announce shout
  header "SHOUT", ">", exchange_name, routing_key
  puts JSON.pretty_generate(body) unless body.empty?

  # Publish
  exchange.publish(body.to_json,
    routing_key: routing_key,
    headers: headers,
    app_id: "contributor",
    content_type: "application/json",
    )

end


# Init ASCII table
config_table = Terminal::Table.new
config_table.title = "Message propagation rules"
config_table.headings = ["queue binding", "topic", "route", "relay", "title"]
config_table.align_column(5, :right)


# Bind every topic
config[:rules].each do |rule_name, rule|
  # Extract information
  catch_subscribe = rule[:subscribe] || true
  catch_topic = rule[:topic].to_s
  catch_routes = rule[:routes].to_s.split(' ')

  if catch_topic.empty? || catch_routes.empty?
    abort "rule [#{rule_name}] is invalid: missing topic / routes"
  end

  # Build / attach to queue
  rule_queue_name = "#{PROXY_IDENT}-#{QUEUE_HOST}-#{rule_name}"

  begin
    # Bind to this topic if not already done
    listen_exchange = topic(channel, catch_topic)

    # Pour this into a queue
    queue = channel.queue(rule_queue_name, auto_delete: false, durable: true)

    # Bind to these events on each route
    catch_routes.each do |route|
      # Bind with this routing key
      queue.bind listen_exchange, routing_key: route
      puts "BIND \t[#{rule_queue_name}] to [#{catch_topic}] / [#{route}] (subscribe: #{catch_subscribe})"

      # Add row to table
      config_table.add_row [rule_queue_name, catch_topic, route, rule[:relay].to_s, rule[:title].to_s ]
    end

  end


  # Subscribe

  queue.subscribe(block: false, manual_ack: SUB_USE_ACK, message_max: SUB_MSG_MAX) do |delivery_info, metadata, payload|

    # Handle the message
    handle_message rule_name, rule, delivery_info, metadata, payload

    # Ack the msg
    # puts "> #{delivery_info.delivery_tag}: nack"
    # channel.nack(delivery_info.delivery_tag)

    # if !SUB_USE_ACK
    #   puts "> #{delivery_info.delivery_tag}: no ack"
    # elsif (100*rand) <= ACK_PERCENT
    #   channel.ack(delivery_info.delivery_tag)
    #   puts "> #{delivery_info.delivery_tag}: ACKED"
    # else
    #   channel.nack(delivery_info.delivery_tag)
    #   puts "> #{delivery_info.delivery_tag}: NOT_ACKED"
    # end

  end

  # End of loop
end


# Display config and susbcribe to queue
puts config_table



puts
puts "ENDED"
