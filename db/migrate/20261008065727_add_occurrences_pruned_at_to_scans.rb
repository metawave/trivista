class AddOccurrencesPrunedAtToScans < ActiveRecord::Migration[8.1]
  def change
    add_column :scans, :occurrences_pruned_at, :datetime
  end
end
