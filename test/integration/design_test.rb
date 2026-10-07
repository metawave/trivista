require "test_helper"

class DesignTest < ActionDispatch::IntegrationTest
  test "renders the styleguide with the real helpers without login" do
    get "/design"

    assert_response :success
    assert_select ".counts .critical", text: /CRITICAL\s*2/
    assert_select ".badge--unknown", text: "UNKNOWN"
    assert_select ".diff__new", text: /\+2/
    assert_select ".swatch-tile[style*='--sev-critical']"
  end
end
