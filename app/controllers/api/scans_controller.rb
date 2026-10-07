# Upload endpoint for CI pipelines (ADR 0004, ADR 0005).
module Api
  class ScansController < ActionController::API
    # ponytail: one import per process at a time keeps memory near 450 MB at the upload limit (Q78);
    # a streaming parser would lift this ceiling.
    IMPORT_LOCK = Mutex.new
    REQUIRED_FIELDS = %i[project repo branch commit].freeze

    before_action :authenticate_upload_token
    before_action :enforce_rate_limit
    before_action :require_multipart

    def create
      return render_error(:bad_request, "report file is missing") unless params[:report].is_a?(ActionDispatch::Http::UploadedFile)

      missing = REQUIRED_FIELDS.reject { params[it].is_a?(String) && params[it].present? }
      return render_error(:bad_request, "missing fields: #{missing.join(", ")}") if missing.any?

      trigger = params[:trigger].presence || "unknown"
      return render_error(:bad_request, "unknown trigger") unless Scan::TRIGGERS.include?(trigger)

      scan = import(trigger)
      render json: { id: scan.id }, status: :created, location: scan_url(scan)
    rescue TrivyReport::InvalidReport => error
      render_error(:bad_request, error.message)
    rescue TrivyReport::UnsupportedReport => error
      render_error(:unprocessable_content, error.message)
    rescue Upload::QuotaExceeded
      render_error(:insufficient_storage, "occurrence quota of the owner is exceeded")
    end

    private
      def import(trigger)
        IMPORT_LOCK.synchronize do
          Upload.new(service_account: @upload_token.service_account, project: params[:project], repo: params[:repo],
            branch: params[:branch], commit: params[:commit], tag: params[:tag].presence, trigger:,
            report: TrivyReport.parse(params[:report].read)).import
        end
      end

      def authenticate_upload_token
        secret = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
        @upload_token = UploadToken.usable.find_by(token_digest: UploadToken.digest(secret)) if secret
        return @upload_token.update_column(:last_used_at, Time.current) if @upload_token

        response.headers["WWW-Authenticate"] = 'Bearer realm="trivista"'
        head :unauthorized
      end

      def enforce_rate_limit
        count = Rails.cache.increment("upload-rate:#{@upload_token.id}", 1, expires_in: 1.hour)
        return head :service_unavailable if count.nil?

        head :too_many_requests if count > Rails.configuration.x.upload_rate_limit
      end

      def require_multipart
        head :unsupported_media_type unless request.content_mime_type&.symbol == :multipart_form
      end

      def render_error(status, message)
        render json: { error: message }, status:
      end
  end
end
