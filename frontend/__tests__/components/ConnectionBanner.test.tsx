import React from "react";
import { render, screen } from "@testing-library/react";
import ConnectionBanner from "@/components/ConnectionBanner";
import { MockRealtimeProvider } from "@/test-utils/realtime";

describe("ConnectionBanner", () => {
  it("returns null when connected", () => {
    const { container } = render(
      <MockRealtimeProvider state={{ connectionState: "connected" }}>
        <ConnectionBanner />
      </MockRealtimeProvider>
    );
    expect(container.firstChild).toBeNull();
  });

  it("shows connecting text when connecting", () => {
    render(
      <MockRealtimeProvider state={{ connectionState: "connecting" }}>
        <ConnectionBanner />
      </MockRealtimeProvider>
    );
    expect(screen.getByText(/Connecting to live updates/)).toBeInTheDocument();
  });

  it("shows disconnected text when disconnected", () => {
    render(
      <MockRealtimeProvider state={{ connectionState: "disconnected" }}>
        <ConnectionBanner />
      </MockRealtimeProvider>
    );
    expect(
      screen.getByText(/Live updates disconnected/)
    ).toBeInTheDocument();
  });
});
