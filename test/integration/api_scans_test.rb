require "test_helper"

class ApiScansTest < ActionDispatch::IntegrationTest
  SHOP_TOKEN = "shop-ci-secret"

  setup do
    Rails.cache.clear
  end

  test "imports a report and points to the new scan" do
    assert_difference -> { branches(:shop_backend_main).scans.count } do
      upload
    end

    assert_response :created
    assert_equal scan_url(Scan.last), response.location
    assert_equal "push", Scan.last.trigger
  end

  test "rejects missing, unknown, expired and revoked tokens" do
    [ nil, "unknown-secret", "expired-secret", "revoked-secret" ].each do |token|
      upload(token:)

      assert_response :unauthorized, token.inspect
      assert_match(/\ABearer/, response.headers["WWW-Authenticate"])
    end
  end

  test "records when a token was last used" do
    freeze_time do
      upload

      assert_equal Time.current, upload_tokens(:shop_ci_token).reload.last_used_at
    end
  end

  test "rate limits uploads per token" do
    with_config(upload_rate_limit: 2) do
      2.times { upload }
      upload

      assert_response :too_many_requests
    end
  end

  test "fails closed when the rate limit counter is unavailable" do
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::NullStore.new
    upload

    assert_response :service_unavailable
  ensure
    Rails.cache = previous
  end

  test "rejects bodies that are not multipart" do
    post api_scans_path, params: { project: "shop" }.to_json,
      headers: { "Authorization" => "Bearer #{SHOP_TOKEN}", "Content-Type" => "application/json" }

    assert_response :unsupported_media_type
  end

  test "rejects missing report and required fields" do
    [ :report, :project, :repo, :branch, :commit ].each do |field|
      upload(params: upload_params.except(field).merge(attachment: report_file("{}")))

      assert_response :bad_request, field.inspect
    end
  end

  test "rejects an unknown trigger" do
    upload(params: upload_params.merge(trigger: "nightly"))

    assert_response :bad_request
  end

  test "rejects invalid json without echoing its content" do
    upload(params: upload_params.merge(report: report_file('{"SchemaVersion": 2, "leaked-secret')))

    assert_response :bad_request
    assert_no_match(/leaked-secret/, response.body)
  end

  test "rejects kubernetes reports and other schema versions" do
    upload(params: upload_params.merge(report: report_file({ "ClusterName" => "prod" }.to_json)))
    assert_response :unprocessable_content

    upload(params: upload_params.merge(report: report_file({ "SchemaVersion" => 1 }.to_json)))
    assert_response :unprocessable_content
  end

  test "rejects reports with an identifying value over the text limit without storing anything" do
    report = JSON.parse(file_fixture("trivy/fs.json").read)
    report["Results"].first["Target"] = "a" * 1_001

    assert_no_difference [ "Scan.count", "Project.count", "Finding.count" ] do
      upload(params: upload_params.merge(project: "new-project", report: report_file(report.to_json)))
    end
    assert_response :unprocessable_content
  end

  test "rejects uploads above the occurrence quota without storing anything" do
    with_config(occurrence_quota: 1) do
      assert_no_difference [ "Scan.count", "Project.count", "Occurrence.count" ] do
        upload(params: upload_params.merge(project: "new-project"))
      end
    end

    assert_response :insufficient_storage
    assert_equal 1, owners(:team_a).reload.occurrence_count
  end

  test "counts stored occurrences against the owner quota" do
    upload

    assert_equal 1 + Scan.last.occurrences.count, owners(:team_a).reload.occurrence_count
  end

  test "resolves projects only in the namespace of the token owner" do
    shop_scans = projects(:shop).repos.sum { it.branches.sum { it.scans.count } }

    upload(token: "alice-ci-secret")

    assert_response :created
    assert_equal owners(:alice), Scan.last.branch.repo.project.owner
    assert_equal shop_scans, projects(:shop).repos.sum { it.branches.sum { it.scans.count } }
  end

  test "new projects start with the visibility of their owner type" do
    upload(params: upload_params.merge(project: "group-project"))
    upload(token: "alice-ci-secret", params: upload_params.merge(project: "user-project"))

    assert_equal "group", owners(:team_a).projects.find_by!(name: "group-project").visibility
    assert_equal "user", owners(:alice).projects.find_by!(name: "user-project").visibility
  end

  test "an upload token does not open other routes" do
    upload
    get scan_path(Scan.last), headers: { "Authorization" => "Bearer #{SHOP_TOKEN}" }

    assert_redirected_to login_path
  end

  test "leaves no multipart tempfiles behind" do
    before = rack_tempfiles

    upload
    upload(params: upload_params.merge(trigger: "nightly"))
    upload(params: upload_params.merge(report: report_file({ "SchemaVersion" => 1 }.to_json)))
    with_config(occurrence_quota: 1) { upload(params: upload_params.merge(project: "quota")) }

    assert_equal before, rack_tempfiles
  end

  test "never writes report content to the log" do
    marker = "TRIVISTA-LOG-MARKER"
    report = JSON.parse(file_fixture("trivy/fs.json").read).merge("Unknown" => marker)
    log = StringIO.new

    with_logger(Logger.new(log)) do
      upload(params: upload_params.merge(report: report_file(report.to_json)))
      upload(params: upload_params.merge(report: report_file("{\"#{marker}")))
    end

    assert_no_match(/#{marker}/o, log.string)
  end

  test "default branch follows main, master, then the first branch" do
    upload(params: upload_params.merge(repo: "frontend", branch: "feature"))
    repo = projects(:shop).repos.find_by!(name: "frontend")
    assert_equal "feature", repo.default_branch.name

    upload(params: upload_params.merge(repo: "frontend", branch: "master"))
    assert_equal "master", repo.reload.default_branch.name

    upload(params: upload_params.merge(repo: "frontend", branch: "main"))
    assert_equal "main", repo.reload.default_branch.name
  end

  test "a manually set default branch stays" do
    upload(params: upload_params.merge(repo: "frontend", branch: "develop"))
    repo = projects(:shop).repos.find_by!(name: "frontend")
    repo.update!(default_branch: repo.branches.find_by!(name: "develop"), default_branch_manual: true)

    upload(params: upload_params.merge(repo: "frontend", branch: "main"))

    assert_equal "develop", repo.reload.default_branch.name
  end

  private
    def upload(token: SHOP_TOKEN, params: upload_params)
      headers = token ? { "Authorization" => "Bearer #{token}" } : {}
      post api_scans_path, params:, headers:
    end

    def upload_params
      { report: report_file(file_fixture("trivy/fs.json").read), project: "shop", repo: "backend",
        branch: "main", commit: "0123abcd", trigger: "push" }
    end

    def report_file(content)
      file = Tempfile.new([ "report", ".json" ])
      file.write(content)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, "application/json")
    end

    def with_config(**settings)
      previous = settings.keys.index_with { Rails.configuration.x.public_send(it) }
      settings.each { Rails.configuration.x.public_send("#{_1}=", _2) }
      yield
    ensure
      previous.each { Rails.configuration.x.public_send("#{_1}=", _2) }
    end

    def with_logger(logger)
      previous = Rails.logger
      Rails.logger = ActionController::Base.logger = ActiveRecord::Base.logger = logger
      yield
    ensure
      Rails.logger = ActionController::Base.logger = ActiveRecord::Base.logger = previous
    end

    def rack_tempfiles
      Dir.glob(File.join(Dir.tmpdir, "RackMultipart*-#{Process.pid}-*")).sort
    end
end
