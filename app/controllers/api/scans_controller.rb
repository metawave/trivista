# Upload endpoint for CI pipelines (ADR 0004, ADR 0005).
module Api
  class ScansController < ActionController::API
    # ponytail: one import per process at a time keeps memory near 450 MB at the upload limit (Q78);
    # a streaming parser would lift this ceiling.
    IMPORT_LOCK = Mutex.new
    REQUIRED_FIELDS = %i[project repo branch commit].freeze

    class TokenRevoked < StandardError; end

    before_action :authenticate_upload_token
    before_action :enforce_rate_limit
    before_action :require_multipart

    def create
      return render_error(:bad_request, "report file is missing") unless params[:report].is_a?(ActionDispatch::Http::UploadedFile)

      missing = REQUIRED_FIELDS.reject { params[it].is_a?(String) && params[it].present? }
      return render_error(:bad_request, "missing fields: #{missing.join(", ")}") if missing.any?

      return render_error(:bad_request, "tag must be a string") unless params[:tag].nil? || params[:tag].is_a?(String)
      # PostgreSQL cannot even look up a NUL byte; the model validations reject the other control characters.
      return render_error(:bad_request, "fields must not contain NUL bytes") if [ *REQUIRED_FIELDS, :tag ].any? { params[it].to_s.include?("\0") }

      trigger = params[:trigger].presence || "unknown"
      return render_error(:bad_request, "unknown trigger") unless Scan::TRIGGERS.include?(trigger)

      scan = import(trigger)
      Rails.event.notify("trivista.scan_uploaded", scan_id: scan.id, project_id: scan.branch.repo.project_id)
      render json: { id: scan.id }, status: :created, location: scan_url(scan)
    rescue TrivyReport::InvalidReport => error
      render_error(:bad_request, error.message)
    rescue ActiveRecord::RecordInvalid => error
      render_error(:bad_request, error.record.errors.full_messages.to_sentence)
    rescue TrivyReport::UnsupportedReport => error
      render_error(:unprocessable_content, error.message)
    rescue TokenRevoked
      reject_token("token revoked")
    rescue Upload::QuotaExceeded
      render_error(:insufficient_storage, "occurrence quota of the owner is exceeded")
    end

    private
      def import(trigger)
        IMPORT_LOCK.synchronize do
          # The token may have been revoked while this upload waited for the lock (ADR 0005).
          raise TokenRevoked unless UploadToken.usable.exists?(@upload_token.id)

          Upload.new(service_account: @upload_token.service_account, project: params[:project], repo: params[:repo],
            branch: params[:branch], commit: params[:commit], tag: params[:tag].presence, trigger:,
            report: TrivyReport.parse(params[:report].read)).import
        end
      end

      def authenticate_upload_token
        secret = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
        @upload_token = UploadToken.usable.find_by(token_digest: UploadToken.digest(secret)) if secret
        if @upload_token
          Rails.event.set_context(upload_token_id: @upload_token.id, service_account_id: @upload_token.service_account_id)
          return @upload_token.update_column(:last_used_at, Time.current)
        end

        reject_token("token")
      end

      def enforce_rate_limit
        count = Rails.cache.increment("upload-rate:#{@upload_token.id}", 1, expires_in: 1.hour)
        return reject(:service_unavailable, "rate limit unavailable") if count.nil?

        reject(:too_many_requests, "rate limit") if count > Rails.configuration.x.upload_rate_limit
      end

      def require_multipart
        reject(:unsupported_media_type, "not multipart") unless request.content_mime_type&.symbol == :multipart_form
      end

      def render_error(status, message)
        report_rejection(status, message)
        render json: { error: message }, status:
      end

      def reject(status, reason)
        report_rejection(status, reason)
        head status
      end

      def reject_token(reason)
        response.headers["WWW-Authenticate"] = 'Bearer realm="trivista"'
        reject(:unauthorized, reason)
      end

      def report_rejection(status, reason)
        Rails.event.notify("trivista.upload_rejected", reason:, status: Rack::Utils.status_code(status))
      end
  end
end
