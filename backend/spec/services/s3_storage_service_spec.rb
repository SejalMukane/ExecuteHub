require "rails_helper"

# S3StorageService is tested with a fully mocked Aws::S3::Client — the test
# suite never makes real AWS calls.
RSpec.describe S3StorageService, type: :service do
  let(:client) { instance_double(Aws::S3::Client) }
  let(:presigner) { instance_double(Aws::S3::Presigner) }
  let(:service) { described_class.new }
  let(:key) { "executehub/projects/project_1/test_runs/run_1/jobs/job_1/screenshots/test.png" }
  let(:tmpfile) { File.join(Dir.mktmpdir, "screenshot.png") }

  before do
    File.write(tmpfile, "PNGDATA")
    ENV["AWS_S3_BUCKET"] = "executehub-bucket"
    ENV["AWS_REGION"] = "us-east-1"
    allow(Aws::S3::Client).to receive(:new).with(region: "us-east-1").and_return(client)
    allow(Aws::S3::Presigner).to receive(:new).with(client: client).and_return(presigner)
  end

  after do
    ENV.delete("AWS_S3_BUCKET")
    ENV.delete("AWS_REGION")
    FileUtils.rm_rf(File.dirname(tmpfile))
  end

  describe "#upload" do
    it "puts the file into the bucket with a content type" do
      expect(client).to receive(:put_object) do |args|
        expect(args[:bucket]).to eq("executehub-bucket")
        expect(args[:key]).to eq(key)
        expect(args[:content_type]).to eq("image/png")
      end.and_return(nil)

      expect(service.upload(tmpfile, key, content_type: "image/png")).to be(true)
    end

    it "wraps SDK failures in S3Error" do
      expect(client).to receive(:put_object).and_raise(Aws::S3::Errors::AccessDenied.new(nil, "denied"))

      expect { service.upload(tmpfile, key) }.to raise_error(S3StorageService::S3Error, /Upload failed/)
    end
  end

  describe "#download" do
    it "streams the object body into a local file" do
      body = double("body")
      allow(body).to receive(:each).and_yield("chunk1").and_yield("chunk2")
      expect(client).to receive(:get_object).with(bucket: "executehub-bucket", key: key)
        .and_return(double(body: body))

      destination = File.join(Dir.mktmpdir, "out.png")
      service.download(key, destination)

      expect(File.read(destination)).to eq("chunk1chunk2")
      FileUtils.rm_rf(File.dirname(destination))
    end
  end

  describe "#signed_url" do
    it "generates a presigned GET URL with the requested expiry" do
      expect(presigner).to receive(:presigned_url)
        .with(:get_object, bucket: "executehub-bucket", key: key, expires_in: 900)
        .and_return("https://s3.example.com/signed-url")

      expect(service.signed_url(key, expires_in: 900)).to eq("https://s3.example.com/signed-url")
    end

    it "wraps signing failures in S3Error" do
      expect(presigner).to receive(:presigned_url).and_raise(Aws::S3::Errors::AccessDenied.new(nil, "denied"))

      expect { service.signed_url(key) }.to raise_error(S3StorageService::S3Error, /Signed URL generation failed/)
    end
  end

  describe "#delete" do
    it "deletes the object" do
      expect(client).to receive(:delete_object).with(bucket: "executehub-bucket", key: key)
      expect(service.delete(key)).to be(true)
    end
  end

  describe "#exists?" do
    it "returns true when the object exists" do
      expect(client).to receive(:head_object).with(bucket: "executehub-bucket", key: key)
      expect(service.exists?(key)).to be(true)
    end

    it "returns false for missing objects" do
      expect(client).to receive(:head_object).and_raise(Aws::S3::Errors::NotFound.new(nil, "nope"))
      expect(service.exists?(key)).to be(false)
    end
  end
end
