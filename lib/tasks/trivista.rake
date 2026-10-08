namespace :trivista do
  desc "Delete the occurrences of scans older than RETENTION_DAYS, keeping their counts (ADR 0002)"
  task retention: :environment do
    result = Retention.new.call
    puts "Retention: removed #{result.occurrences} occurrences of #{result.scans} scans"
  end
end
