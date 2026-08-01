require "open3"

# DockerService is the ONLY place in the application that talks to Docker.
# Controllers, workers and other services never shell out to docker directly —
# they use this service so container operations stay encapsulated and testable.
#
# Responsibilities:
#   - create a container (docker create)
#   - start a container (docker start)
#   - stream logs while a container runs (docker logs -f)
#   - copy artifacts out of a container (docker cp)
#   - read the exit code (docker inspect)
#   - destroy a container (docker rm -f)
#
# A single instance manages a single container at a time and tracks it via a
# lightweight Container struct. All commands are run through Open3 (argument
# array form) so paths/commands never go through a shell.
class DockerService
  # Raised whenever a docker command exits non-zero.
  class DockerError < StandardError; end

  # Handle for a created container; keeps the id + human name together.
  class Container
    attr_reader :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end
  end

  def initialize(binary: nil)
    @binary = binary || ENV.fetch("DOCKER_BINARY", "docker")
  end

  # docker create — returns a Container (not yet started).
  def create(name:, image:, command:, workdir: nil, env: {})
    args = [@binary, "create", "--name", name]
    args += ["--workdir", workdir] if workdir
    env.each { |key, value| args += ["-e", "#{key}=#{value}"] }
    args += [image]
    args += Array(command)

    id = run(*args).strip
    Container.new(id: id, name: name)
  end

  # docker start — starts the container and returns it.
  def start(container)
    run(@binary, "start", container.id)
    container
  end

  # docker logs -f — follows the container's combined output, yielding each
  # line as it is emitted. Returns when the container exits and its logs have
  # been flushed, so the caller can inspect the exit code afterwards.
  #
  #   docker.stream_logs(container) { |line| ... }
  def stream_logs(container)
    command = [@binary, "logs", "-f", container.id]
    success = Open3.popen2e(*command) do |_stdin, output, wait_thread|
      output.each_line do |line|
        yield line.chomp
      end
      wait_thread.value.success?
    end

    unless success
      raise DockerError, "docker logs #{container.id} failed"
    end
  end

  # docker inspect -f {{.State.ExitCode}} — the container's exit code.
  def exit_code(container)
    run(@binary, "inspect", "-f", "{{.State.ExitCode}}", container.id).strip.to_i
  end

  # docker cp — copies a path out of the container to a local destination.
  def copy(container, source:, destination:)
    run(@binary, "cp", "#{container.id}:#{source}", destination.to_s)
  end

  # docker rm -f — destroys the container. No-op if it is already gone.
  def destroy(container)
    run(@binary, "rm", "-f", container.id)
  rescue DockerError
    nil
  end

  private

  # Runs a docker command via Open3 (no shell interpolation). Raises
  # DockerError on non-zero exit and returns captured stdout on success.
  def run(*args)
    stdout, stderr, status = Open3.capture3(*args)
    unless status.success?
      message = stderr.strip
      raise DockerError, "#{args.join(" ")} failed: #{message}"
    end
    stdout
  end
end
