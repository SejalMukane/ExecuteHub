import React from "react";
import { render, screen } from "@testing-library/react";
import {
  useDashboard,
  useQueue,
  useWorkers,
} from "@/context/RealtimeContext";
import { MockRealtimeProvider } from "@/test-utils/realtime";

function DashboardConsumer() {
  const { metrics, queue, workers, connectionState } = useDashboard();
  return (
    <div>
      <div data-testid="connection">{connectionState}</div>
      <div data-testid="metrics">{metrics ? JSON.stringify(metrics) : "no-metrics"}</div>
      <div data-testid="queue">{queue ? queue.depth : "no-queue"}</div>
      <div data-testid="workers">{workers.length}</div>
    </div>
  );
}

describe("useDashboard", () => {
  it("exposes metrics, queue, workers and connection state", () => {
    render(
      <MockRealtimeProvider
        state={{
          connectionState: "connected",
          metrics: { metrics: { runs: { total: 5 } } },
          queue: { queue: { depth: 12 } },
          workers: [
            {
              worker_name: "w1",
              status: "online",
              last_heartbeat_at: new Date().toISOString(),
            },
          ],
        }}
      >
        <DashboardConsumer />
      </MockRealtimeProvider>
    );

    expect(screen.getByTestId("connection").textContent).toBe("connected");
    expect(screen.getByTestId("metrics").textContent).toContain('"total":5');
    expect(screen.getByTestId("queue").textContent).toBe("12");
    expect(screen.getByTestId("workers").textContent).toBe("1");
  });

  it("falls back to metrics.queue when queue event is missing", () => {
    render(
      <MockRealtimeProvider
        state={{
          metrics: { metrics: { runs: {} }, queue: { depth: 3 } },
        }}
      >
        <DashboardConsumer />
      </MockRealtimeProvider>
    );

    expect(screen.getByTestId("queue").textContent).toBe("3");
  });
});

function QueueConsumer() {
  const { queue, connectionState } = useQueue();
  return (
    <div>
      <div data-testid="q-connection">{connectionState}</div>
      <div data-testid="q-depth">{queue ? queue.depth : "none"}</div>
    </div>
  );
}

describe("useQueue", () => {
  it("returns queue and connection state", () => {
    render(
      <MockRealtimeProvider state={{ queue: { queue: { depth: 7 } }, connectionState: "connected" }}>
        <QueueConsumer />
      </MockRealtimeProvider>
    );

    expect(screen.getByTestId("q-connection").textContent).toBe("connected");
    expect(screen.getByTestId("q-depth").textContent).toBe("7");
  });
});

function WorkersConsumer() {
  const { workers, connectionState } = useWorkers();
  return (
    <div>
      <div data-testid="w-connection">{connectionState}</div>
      <div data-testid="w-count">{workers.length}</div>
    </div>
  );
}

describe("useWorkers", () => {
  it("returns workers and connection state", () => {
    render(
      <MockRealtimeProvider
        state={{
          workers: [
            { worker_name: "w1", status: "online" },
            { worker_name: "w2", status: "offline" },
          ],
          connectionState: "disconnected",
        }}
      >
        <WorkersConsumer />
      </MockRealtimeProvider>
    );

    expect(screen.getByTestId("w-connection").textContent).toBe("disconnected");
    expect(screen.getByTestId("w-count").textContent).toBe("2");
  });
});
