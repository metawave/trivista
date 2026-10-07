require "test_helper"
require "socket"

class UploadBodyLimitTest < ActiveSupport::TestCase
  LIMIT = 1024

  setup do
    @port = free_port
    @pid = Process.spawn(
      { "PORT" => @port.to_s, "UPLOAD_MAX_BYTES" => LIMIT.to_s, "RAILS_ENV" => "test" },
      "bundle", "exec", "puma", "-C", "config/puma.rb", "config.ru",
      chdir: Rails.root.to_s, out: File::NULL, err: File::NULL
    )
    wait_for_server
  end

  teardown do
    Process.kill("TERM", @pid)
    Process.wait(@pid)
  end

  test "rejects a body above the limit announced via content-length" do
    response = raw_request(<<~HTTP + "x" * (LIMIT + 1))
      POST /up HTTP/1.1\r
      Host: localhost\r
      Content-Length: #{LIMIT + 1}\r
      Connection: close\r
      \r
    HTTP

    assert_match %r{\AHTTP/1\.1 413}, response
  end

  test "rejects a chunked body that grows above the limit" do
    chunk = "x" * 512
    chunks = Array.new(3) { "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n" }.join
    response = raw_request(<<~HTTP + chunks + "0\r\n\r\n")
      POST /up HTTP/1.1\r
      Host: localhost\r
      Transfer-Encoding: chunked\r
      Connection: close\r
      \r
    HTTP

    assert_match %r{\AHTTP/1\.1 413}, response
  end

  test "passes a body within the limit to the app" do
    response = raw_request(<<~HTTP + "x" * LIMIT)
      POST /up HTTP/1.1\r
      Host: localhost\r
      Content-Length: #{LIMIT}\r
      Connection: close\r
      \r
    HTTP

    assert_no_match %r{\AHTTP/1\.1 413}, response
  end

  private
    def free_port
      server = TCPServer.new("127.0.0.1", 0)
      server.addr[1]
    ensure
      server&.close
    end

    def wait_for_server
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
      loop do
        TCPSocket.new("127.0.0.1", @port).close
        return
      rescue Errno::ECONNREFUSED
        raise "Puma did not start within 30 seconds" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.1
      end
    end

    def raw_request(request)
      TCPSocket.open("127.0.0.1", @port) do |socket|
        begin
          socket.write(request)
        rescue Errno::EPIPE, Errno::ECONNRESET
          # Puma may close the connection before the whole body is sent.
        end
        socket.read
      rescue Errno::ECONNRESET
        ""
      end
    end
end
