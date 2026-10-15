# Static stylesheets and scripts declare their charset (ASVS V4.1.1).
Rack::Mime::MIME_TYPES.merge!(".css" => "text/css; charset=utf-8", ".js" => "text/javascript; charset=utf-8")
