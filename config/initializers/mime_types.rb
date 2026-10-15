# Static files declare their charset (ASVS V4.1.1).
Rack::Mime::MIME_TYPES.merge!(".css" => "text/css; charset=utf-8", ".js" => "text/javascript; charset=utf-8",
  ".html" => "text/html; charset=utf-8", ".txt" => "text/plain; charset=utf-8", ".svg" => "image/svg+xml; charset=utf-8")
