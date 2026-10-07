class Finding < ApplicationRecord
  TYPES = %w[vulnerability misconfiguration secret license].freeze

  belongs_to :project
  has_many :occurrences, dependent: :delete_all

  enum :finding_type, TYPES.index_by(&:itself), validate: true
end
