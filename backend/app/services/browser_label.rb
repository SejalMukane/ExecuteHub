# BrowserLabel maps the configured Playwright Docker image to a human-friendly
# browser name used on TestResults and the frontend debugging views.
class BrowserLabel
  def self.call
    image = (Rails.configuration.executehub["worker"] || {})["image"].to_s
    case image
    when /webkit/i then "WebKit"
    when /firefox/i then "Firefox"
    when /chromium/i then "Chromium"
    else "Chrome"
    end
  end
end
