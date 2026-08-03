"use client";

import React from "react";
import { Loader2, Wifi, WifiOff } from "lucide-react";
import { useConnectionState } from "@/context/RealtimeContext";

export default function ConnectionBanner() {
  const state = useConnectionState();

  if (state === "connected") return null;

  const isConnecting = state === "connecting";

  return (
    <div
      className={`fixed top-0 left-0 right-0 z-[100] px-4 py-2 text-sm font-medium flex items-center justify-center gap-2 ${
        isConnecting
          ? "bg-amber-500/10 text-amber-400 border-b border-amber-500/20"
          : "bg-red-500/10 text-red-400 border-b border-red-500/20"
      }`}
    >
      {isConnecting ? (
        <>
          <Loader2 className="w-4 h-4 animate-spin" />
          Connecting to live updates…
        </>
      ) : (
        <>
          <WifiOff className="w-4 h-4" />
          Live updates disconnected — reconnecting automatically
        </>
      )}
    </div>
  );
}
