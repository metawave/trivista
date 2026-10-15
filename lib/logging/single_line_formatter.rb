require "logger"

# Rails' formatter writes messages as they come; a value from a request could then forge extra log lines.
# This one escapes line breaks and stamps every line in UTC (ASVS V16.4.1, V16.2.2).
class SingleLineFormatter < ::Logger::Formatter
  def call(severity, time, _progname, message)
    "#{time.utc.iso8601(3)} #{severity} #{msg2str(message).gsub(/\r|\n/, "\r" => "\\r", "\n" => "\\n")}\n"
  end
end
