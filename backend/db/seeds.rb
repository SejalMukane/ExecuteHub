[
  { name: "Chrome", version: "128", tag: "selenium/standalone-chrome:128.0" },
  { name: "Chrome", version: "127", tag: "selenium/standalone-chrome:127.0" },
  { name: "Firefox", version: "129", tag: "selenium/standalone-firefox:129.0" }
].each do |image|
  BrowserImage.find_or_create_by!(name: image[:name], version: image[:version], tag: image[:tag])
end

puts "Seeded #{BrowserImage.count} browser images"

[
  { name: "Smoke Tests", description: "Fast sanity check of critical user flows", total_tests: 120 },
  { name: "Regression", description: "Full regression suite across all features", total_tests: 850 },
  { name: "Checkout", description: "End-to-end purchase and payment flows", total_tests: 52 }
].each do |suite|
  TestSuite.find_or_create_by!(name: suite[:name]) do |s|
    s.description = suite[:description]
    s.total_tests = suite[:total_tests]
  end
end

puts "Seeded #{TestSuite.count} test suites"