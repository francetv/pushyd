# overload log bmcDaemonLib to handle info log level
module BmcDaemonLib
	module LoggerHelper
		private
			def log severity, message, details
			  return puts "LoggerHelper.log: missing logger (#{get_class_name})" unless logger
			  logger.add(severity, message, full_context, details) unless BmcDaemonLib::Conf[:logs][:level] == 'info' && severity != 1
			end
	end
end