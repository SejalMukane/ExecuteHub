[
  { name: "Chrome", version: "128", tag: "selenium/standalone-chrome:128.0" },
  { name: "Chrome", version: "127", tag: "selenium/standalone-chrome:127.0" },
  { name: "Firefox", version: "129", tag: "selenium/standalone-firefox:129.0" }
].each do |image|
  BrowserImage.find_or_create_by!(name: image[:name], version: image[:version], tag: image[:tag])
end

puts "Seeded #{BrowserImage.count} browser images"
