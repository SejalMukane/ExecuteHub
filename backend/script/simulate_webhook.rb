# Simulates a GitHub webhook delivery against the local Rails server.
#
# Usage (must run inside Rails):
#   ruby bin/rails runner script/simulate_webhook.rb [webhook_slug] [event]
#
# It finds the webhook in the DB, builds a fake push payload for the linked
# repository, signs it with the stored secret, and POSTs it to the local
# server. Also sends an invalid-signature request to demonstrate rejection.

require "net/http"
require "json"
require "openssl"
require "uri"

slug = ARGV[0] || "testslug123"
event = ARGV[1] || "push"
base = ENV.fetch("BASE_URL", "http://127.0.0.1:3001")

webhook = GithubWebhook.find_by(slug: slug)
abort "Webhook with slug '#{slug}' not found. Create it first (see tmp/setup_webhook_test.rb)." unless webhook

repo = webhook.github_repository
payload = {
  ref: "refs/heads/#{repo.default_branch || "main"}",
  before: "a" * 40,
  after: "b" * 40,
  repository: {
    name: repo.full_name.split("/").last,
    full_name: repo.full_name,
    html_url: repo.html_url,
    default_branch: repo.default_branch
  },
  pusher: { name: "octocat", email: "octocat@github.com" }
}.to_json

def sign(secret, body)
  "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
end

def post_delivery(uri, body, signature, event, delivery_id)
  req = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/json"
  req["X-GitHub-Event"] = event
  req["X-GitHub-Delivery"] = delivery_id
  req["X-Hub-Signature-256"] = signature
  req.body = body
  Net::HTTP.new(uri.host, uri.port).request(req)
end

uri = URI("#{base}/api/v1/github/webhooks/#{webhook.slug}")
puts "Webhook: #{webhook.url}"

res = post_delivery(uri, payload, sign(webhook.secret, payload), event, "sim-#{event}-#{Time.now.to_i}")
puts "valid signature   -> #{res.code}"

res = post_delivery(uri, payload, "sha256=#{"0" * 64}", event, "sim-invalid-#{Time.now.to_i}")
puts "invalid signature -> #{res.code}"
