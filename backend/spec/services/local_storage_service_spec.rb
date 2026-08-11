require "rails_helper"

RSpec.describe LocalStorageService, type: :service do
  let(:service) { described_class.new }
  let(:key) { "executehub/projects/project_1/test_runs/run_1/jobs/job_1/screenshots/test.png" }
  let(:tmpdir) { Dir.mktmpdir }
  let(:source) { File.join(tmpdir, "source.png") }

  before { File.write(source, "PNGDATA") }
  after { FileUtils.rm_rf(tmpdir) }

  describe "#upload" do
    it "copies the file under the key" do
      service.upload(source, key, content_type: "image/png")

      expect(File.exist?(LocalStorageService::ROOT.join(key))).to be(true)
      expect(File.read(LocalStorageService::ROOT.join(key))).to eq("PNGDATA")
    end
  end

  describe "#download" do
    it "copies the stored file into a local path" do
      service.upload(source, key)
      destination = File.join(tmpdir, "out.png")

      service.download(key, destination)

      expect(File.read(destination)).to eq("PNGDATA")
    end
  end

  describe "#signed_url" do
    it "returns nil — local files are streamed through the Rails API instead" do
      expect(service.signed_url(key, expires_in: 900)).to be_nil
    end
  end

  describe "#exists?" do
    it "reports stored keys and misses" do
      service.upload(source, key)
      expect(service.exists?(key)).to be(true)
      expect(service.exists?("executehub/unknown.png")).to be(false)
    end
  end

  describe "#delete" do
    it "removes the stored file" do
      service.upload(source, key)
      service.delete(key)
      expect(service.exists?(key)).to be(false)
    end
  end
end
