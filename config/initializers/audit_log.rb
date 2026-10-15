# Writes the trivista.* events from Rails.event as one JSON line each, with the actor from the event context (ASVS V16.3).
class AuditLog
  def emit(event)
    Rails.logger.info(JSON.generate(event: event[:name], **event[:payload], **event[:context],
      at: Time.at(event[:timestamp] / 1_000_000_000r).utc.iso8601(3)))
  end
end

Rails.event.subscribe(AuditLog.new) { it[:name].start_with?("trivista.") }
