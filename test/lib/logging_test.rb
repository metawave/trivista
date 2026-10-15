require "test_helper"
require Rails.root.join("lib/logging/single_line_formatter")

class LoggingTest < ActiveSupport::TestCase
  test "log lines cannot be split by values from a request" do
    line = SingleLineFormatter.new.call("INFO", Time.utc(2026, 10, 15, 12), nil, "error=x\nINFO forged\r")

    assert_equal "2026-10-15T12:00:00.000Z INFO error=x\\nINFO forged\\r\n", line
  end

  test "audit events become one JSON line with the actor" do
    output = StringIO.new
    previous, Rails.logger = Rails.logger, ActiveSupport::Logger.new(output)

    Rails.event.set_context(user_id: 7)
    Rails.event.notify("trivista.example", reason: "a\nb")

    entry = JSON.parse(output.string.lines.sole)
    assert_equal({ "event" => "trivista.example", "reason" => "a\nb", "user_id" => 7 }, entry.except("at"))
  ensure
    Rails.logger = previous
    Rails.event.clear_context
  end
end
