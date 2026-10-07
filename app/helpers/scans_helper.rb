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

  def severity_badge(severity, outline: false)
    tag.span(severity, class: [ "badge", "badge--#{severity.downcase}", ("badge--outline" if outline) ])
  end

  def type_count(counts, finding_type)
    counts.fetch(finding_type, {}).values.sum
  end

  # An empty selection shows all severities; a chip toggles its severity in the shown set.
  def shown_severities(selected)
    selected.presence || Occurrence::SEVERITIES
  end

  def severity_toggle_param(selected, severity)
    shown = shown_severities(selected)
    toggled = Occurrence::SEVERITIES & (shown.include?(severity) ? shown - [ severity ] : shown + [ severity ])
    toggled.empty? || toggled == Occurrence::SEVERITIES ? nil : toggled.join(",")
  end
end
