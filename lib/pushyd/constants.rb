# Constants: global
MSG_SEND                = "SEND"
MSG_RECV                = "RECV"
WAY_PROP                = "PROP"

# Constants: proxy
PROXY_MESSAGE_MAX       = 1
PROXY_USE_ACK           = false

# Constants: shouter
SHOUTER_SENTAT_DECIMALS = 6

# Constants: logger
LOG_ROTATION            = "daily"

LOG_HEADER_TIME         = "%Y-%m-%d %H:%M:%S"
LOG_HEADER_FORMAT       = "%s \t%d\t%-8s %-15s "
LOG_MESSAGE_TRIM        = 200
LOG_MESSAGE_TEXT        = "%s%s"
LOG_MESSAGE_ARRAY       = "%s     %s"
LOG_MESSAGE_HASH        = "%s     %-20s %s\n"

# Constants: logger app-specific prefix
LOG_PREFIX_FORMAT       = nil

# Constants: AMQP protocol
AMQP_HEARTBEAT_INTERVAL = 30
AMQP_RECOVERY_INTERVAL  = 5
AMQP_PREFETCH           = 1
