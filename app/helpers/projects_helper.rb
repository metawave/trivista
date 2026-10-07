module ProjectsHelper
  def severity_counts(counts)
    present = Occurrence::SEVERITIES.select { counts&.fetch(it, 0).to_i.positive? }
    return tag.span("–", class: "mono muted") if present.empty?

    tag.span(class: "counts") do
      safe_join(present.map do |severity|
        tag.span(class: severity.downcase, title: severity) do
          tag.b(severity.first, aria: { hidden: true }) + tag.span(severity, class: "visually-hidden") + " #{counts[severity]}"
        end
      end)
    end
  end
end
