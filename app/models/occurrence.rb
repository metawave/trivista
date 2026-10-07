class Occurrence < ApplicationRecord
  SEVERITIES = %w[CRITICAL HIGH MEDIUM LOW UNKNOWN].freeze

  belongs_to :scan
  belongs_to :finding

  enum :severity, SEVERITIES.index_by(&:itself), prefix: true, validate: true
end
