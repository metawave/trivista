module ScansHelper
  # Report URLs come from external uploaders; only absolute http(s) URLs become links (ADR 0003).
  def report_link(text, url)
    uri = URI.parse(url.to_s)
    return text unless uri.is_a?(URI::HTTP) && uri.host.present?

    link_to text, uri.to_s, rel: "noopener noreferrer nofollow", target: "_blank"
  rescue URI::InvalidURIError
    text
  end

  def finding_location(finding)
    [ finding.pkg_name, finding.target ].compact_blank.join(" · ")
  end
end
