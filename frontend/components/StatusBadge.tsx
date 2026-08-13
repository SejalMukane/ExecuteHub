"use client";

import React from "react";

export type StatusTone = "blue" | "yellow" | "green" | "red" | "neutral";

const TONE_CLASSES: Record<StatusTone, string> = {
  blue: "bg-blue-500/10 text-blue-400 border-blue-500/30",
  yellow: "bg-amber-500/10 text-amber-400 border-amber-500/30",
  green: "bg-emerald-500/10 text-emerald-400 border-emerald-500/30",
  red: "bg-red-500/10 text-red-400 border-red-500/30",
  neutral: "bg-neutral-800 text-neutral-400 border-neutral-700/50",
};

const DOT_CLASSES: Record<StatusTone, string> = {
  blue: "bg-blue-400",
  yellow: "bg-amber-400",
  green: "bg-emerald-400",
  red: "bg-red-400",
  neutral: "bg-neutral-500",
};

// Maps a status string to its visual tone.
// Queued -> blue, Running/Scheduling -> yellow, Completed -> green, Failed -> red.
export function statusTone(status: string): StatusTone {
  switch (status) {
    case "queued":
    case "retrying":
    case "pending":
      return "blue";
    case "running":
    case "scheduling":
    case "uploading_artifacts":
      return "yellow";
    case "completed":
    case "success":
    case "passed":
    case "approved":
      return "green";
    case "failed":
    case "error":
    case "blocked":
      return "red";
    default:
      return "neutral";
  }
}

export default function StatusBadge({
  status,
  pulse = false,
}: {
  status: string;
  pulse?: boolean;
}) {
  const tone = statusTone(status);
  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium border ${TONE_CLASSES[tone]}`}
    >
      {pulse && <span className={`w-1.5 h-1.5 rounded-full ${DOT_CLASSES[tone]} animate-pulse`} />}
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}

export function ProgressBar({ value }: { value: number }) {
  const clamped = Math.max(0, Math.min(100, value));
  return (
    <div className="flex items-center gap-3">
      <div className="w-28 h-1.5 rounded-full bg-neutral-900 overflow-hidden">
        <div className="h-full rounded-full bg-emerald-500" style={{ width: `${clamped}%` }} />
      </div>
      <span className="text-xs text-neutral-400 tabular-nums">{clamped}%</span>
    </div>
  );
}
