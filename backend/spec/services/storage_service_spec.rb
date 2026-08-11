require "rails_helper"

RSpec.describe StorageService, type: :service do
  around do |example|
    original = {
      access: ENV["AWS_ACCESS_KEY_ID"],
      secret: ENV["AWS_SECRET_ACCESS_KEY"],
      bucket: ENV["AWS_S3_BUCKET"]
    }
    example.run
  ensure
    ENV["AWS_ACCESS_KEY_ID"] = original[:access]
    ENV["AWS_SECRET_ACCESS_KEY"] = original[:secret]
    ENV["AWS_S3_BUCKET"] = original[:bucket]
  end

  def clear_aws_env
    ENV.delete("AWS_ACCESS_KEY_ID")
    ENV.delete("AWS_SECRET_ACCESS_KEY")
    ENV.delete("AWS_S3_BUCKET")
  end

  it "selects S3 when credentials and a bucket are configured" do
    ENV["AWS_ACCESS_KEY_ID"] = "AKIA"
    ENV["AWS_SECRET_ACCESS_KEY"] = "secret"
    ENV["AWS_S3_BUCKET"] = "executehub-artifacts"

    expect(StorageService.adapter).to eq(S3StorageService)
    expect(StorageService.storage_backend).to eq("s3")
  end

  it "falls back to local storage when credentials are missing" do
    clear_aws_env
    ENV["AWS_S3_BUCKET"] = "executehub-artifacts"

    expect(StorageService.adapter).to eq(LocalStorageService)
    expect(StorageService.storage_backend).to eq("local")
  end

  it "falls back to local storage when no bucket is configured" do
    clear_aws_env
    ENV["AWS_ACCESS_KEY_ID"] = "AKIA"
    ENV["AWS_SECRET_ACCESS_KEY"] = "secret"

    expect(StorageService.adapter).to eq(LocalStorageService)
  end

  it "both adapters expose the same storage interface" do
    %i[upload download signed_url delete exists?].each do |method|
      expect(S3StorageService).to respond_to(method)
      expect(LocalStorageService).to respond_to(method)
    end
  end
end
