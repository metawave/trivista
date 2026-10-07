module ProjectsHelper
  def severity_counts(counts)
    present = Occurrence::SEVERITIES.select { counts&.fetch(it, 0).to_i.positive? }
    return "–" if present.empty?

    safe_join(present.map { tag.span("#{it} #{counts[it]}", class: "severity severity-#{it.downcase}") }, " ")
  end
end
