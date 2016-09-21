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
LOGGER_FORMAT = {
  context: {
    caller: "%-17s",
    rule:   "%-20s",
    }
  # array:    "PA%s     %s",
  # hash:     "PH%s     %-20s %s",
  }


# Constants: logger app-specific prefix
#LOG_PREFIX_FORMAT       = "(%-12s) (%-12s)"

