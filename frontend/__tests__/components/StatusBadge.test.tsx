import React from "react";
import { render, screen } from "@testing-library/react";
import StatusBadge from "@/components/StatusBadge";

describe("StatusBadge", () => {
  it("renders the status capitalized", () => {
    render(<StatusBadge status="running" />);
    expect(screen.getByText("Running")).toBeInTheDocument();
  });

  it("applies the tone classes for a failed status", () => {
    const { container } = render(<StatusBadge status="failed" />);
    expect(container.firstChild).toHaveClass("text-red-400");
    expect(container.firstChild).toHaveClass("border-red-500/30");
  });

  it("shows a pulsing dot when requested", () => {
    const { container } = render(<StatusBadge status="running" pulse />);
    expect(container.querySelector(".animate-pulse")).toBeInTheDocument();
  });

  it("does not show a pulsing dot by default", () => {
    const { container } = render(<StatusBadge status="running" />);
    expect(container.querySelector(".animate-pulse")).not.toBeInTheDocument();
  });
});
