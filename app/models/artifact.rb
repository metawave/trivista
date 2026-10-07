class Artifact < ApplicationRecord
  CATEGORIES = %w[container_image source vm cyclonedx spdx aws_account].freeze

  belongs_to :project
  has_many :scans, dependent: :delete_all

  enum :category, CATEGORIES.index_by(&:itself), validate: true
end
