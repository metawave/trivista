require "test_helper"

# Browser-side protections (ADR 0010, ASVS V3 and V14.3).
class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "pages carry a strict content security policy with nonces" do
    sign_in
    get root_path

    policy = response.headers["Content-Security-Policy"]
    assert_match "default-src 'none'", policy
    assert_match "frame-ancestors 'none'", policy
    assert_match "base-uri 'none'", policy
    assert_match "object-src 'none'", policy
    assert_match(/script-src 'self' 'nonce-[^']+'/, policy)
    assert_select "script[type=importmap][nonce]"
  end

  test "the sign-in form may submit to the identity provider" do
    get login_path

    assert_select "script[type=importmap][nonce]"
    assert_match %r{form-action 'self' https://idp\.example\.com}, response.headers["Content-Security-Policy"]
  end

  test "pages are not stored by browsers or proxies" do
    sign_in
    get root_path

    assert_match "no-store", response.headers["Cache-Control"]
  end

  test "pages isolate their browsing context and resources" do
    get login_path

    assert_equal "same-origin", response.headers["Cross-Origin-Opener-Policy"]
    assert_equal "same-origin", response.headers["Cross-Origin-Resource-Policy"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "signing out clears cached pages and storage in the browser" do
    sign_in
    delete logout_path

    assert_equal '"cache", "storage"', response.headers["Clear-Site-Data"]
  end
end
