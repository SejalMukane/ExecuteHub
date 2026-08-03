"use client";

import React from "react";
import { RealtimeContext } from "@/context/RealtimeContext";

type RealtimeState = {
  metrics: any;
  queue: any;
  workers: any[];
  testRuns: Record<number, any>;
  activities: any[];
  connectionState: "connecting" | "connected" | "disconnected";
};

const defaultState: RealtimeState = {
  metrics: null,
  queue: null,
  workers: [],
  testRuns: {},
  activities: [],
  connectionState: "connecting",
};

export function MockRealtimeProvider({
  children,
  state = {},
}: {
  children: React.ReactNode;
  state?: Partial<RealtimeState>;
}) {
  const value = {
    ...defaultState,
    ...state,
    reconnect: jest.fn(),
  };

  return (
    <RealtimeContext.Provider value={value}>{children}</RealtimeContext.Provider>
  );
}
