require "rails_helper"

RSpec.describe DockerService, type: :service do
  subject(:service) { described_class.new(binary: "docker") }

  let(:open3) { class_double("Open3").as_stubbed_const }
  let(:container) { described_class::Container.new(id: "abc123", name: "my-container") }
  let(:success) { instance_double(Process::Status, success?: true) }

  describe "#create" do
    it "returns a Container and builds the docker create arguments" do
      expect(open3).to receive(:capture3).with(
        "docker", "create", "--name", "my-container", "--workdir", "/app",
        "-e", "FOO=bar", "playwright:latest", "npx", "playwright", "test"
      ).and_return(["container-id\n", "", success])

      result = service.create(
        name: "my-container",
        image: "playwright:latest",
        command: ["npx", "playwright", "test"],
        workdir: "/app",
        env: { "FOO" => "bar" }
      )

      expect(result).to be_a(described_class::Container)
      expect(result.id).to eq("container-id")
      expect(result.name).to eq("my-container")
    end

    it "omits the workdir and env flags when they are not provided" do
      expect(open3).to receive(:capture3).with(
        "docker", "create", "--name", "my-container", "playwright:latest", "test"
      ).and_return(["container-id\n", "", success])

      service.create(name: "my-container", image: "playwright:latest", command: ["test"])
    end

    it "raises DockerError when docker exits non-zero" do
      expect(open3).to receive(:capture3)
        .and_return(["", "Error: No such image", instance_double(Process::Status, success?: false)])

      expect { service.create(name: "x", image: "missing:latest", command: []) }
        .to raise_error(DockerService::DockerError, /No such image/)
    end
  end

  describe "#start" do
    it "runs docker start with the container id" do
      expect(open3).to receive(:capture3).with("docker", "start", "abc123")
        .and_return(["", "", success])

      expect(service.start(container)).to eq(container)
    end
  end

  describe "#stream_logs" do
    def output_yielding(*lines)
      output = instance_double(IO)
      allow(output).to receive(:each_line) { |&block| lines.each { |line| block.call(line) } }
      output
    end

    it "yields each streamed line and does not raise on a clean exit" do
      wait_thread = instance_double(Process::Waiter, value: success)
      expect(open3).to receive(:popen2e).with("docker", "logs", "-f", "abc123")
        .and_yield(nil, output_yielding("first\n", "second\n"), wait_thread)

      yielded = []
      expect { service.stream_logs(container) { |line| yielded << line } }.not_to raise_error
      expect(yielded).to eq(%w[first second])
    end

    it "raises DockerError when the container exits unsuccessfully" do
      failed = instance_double(Process::Status, success?: false)
      wait_thread = instance_double(Process::Waiter, value: failed)
      expect(open3).to receive(:popen2e).with("docker", "logs", "-f", "abc123")
        .and_yield(nil, output_yielding("line\n"), wait_thread)

      expect { service.stream_logs(container) { |_line| } }
        .to raise_error(DockerService::DockerError, /docker logs abc123 failed/)
    end
  end

  describe "#exit_code" do
    it "parses the inspect output into an integer" do
      expect(open3).to receive(:capture3).with(
        "docker", "inspect", "-f", "{{.State.ExitCode}}", "abc123"
      ).and_return(["1\n", "", success])

      expect(service.exit_code(container)).to eq(1)
    end
  end

  describe "#copy" do
    it "copies the container path to the destination" do
      expect(open3).to receive(:capture3).with(
        "docker", "cp", "abc123:/app/artifacts", "/tmp/dest"
      ).and_return(["", "", success])

      service.copy(container, source: "/app/artifacts", destination: "/tmp/dest")
    end
  end

  describe "#destroy" do
    it "force-removes the container" do
      expect(open3).to receive(:capture3).with("docker", "rm", "-f", "abc123")
        .and_return(["", "", success])

      service.destroy(container)
    end

    it "swallows DockerError when the container is already gone" do
      expect(open3).to receive(:capture3)
        .and_raise(DockerService::DockerError, "No such container")

      expect { service.destroy(container) }.not_to raise_error
    end
  end
end
