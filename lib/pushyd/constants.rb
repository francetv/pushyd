# Constants: global
MSG_SEND                = "SEND"
MSG_RECV                = "RECV"
MSG_RLAY                = "RLAY"

# Constants: AMQP protocol
AMQP_HEARTBEAT_INTERVAL = 30
AMQP_RECOVERY_INTERVAL  = 5
AMQP_PREFETCH           = 3
AMQP_MANUAL_ACK         = false

# Constants: shouter
SHOUTER_SENTAT_DECIMALS = 6

# Constants: logger
LOG_HEADER_TIME         = "%Y-%m-%d %H:%M:%S"
LOG_HEADER_FORMAT       = "%s \t%d\t%-8s %-15s "
LOG_MESSAGE_TRIM        = 500
LOG_MESSAGE_TEXT        = "%s%s"
LOG_MESSAGE_ARRAY       = "%s     %s"
LOG_MESSAGE_HASH        = "%s     %-20s %s\n"

# Constants: logger app-specific prefix
#LOG_PREFIX_FORMAT       = "(%-12s) (%-12s)"
LOG_PREFIX_FORMAT       = "%-20s "
