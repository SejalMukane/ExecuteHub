"use client";

import React, { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Loader2,
  Cpu,
  MemoryStick,
  Activity,
  Box,
  HardDrive,
  Play,
  Clock,
  Radio,
} from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge, { StatusTone } from "@/components/StatusBadge";
import { useWorkers, useConnectionState } from "@/context/RealtimeContext";
import { useAuth } from "@/context/AuthContext";

const COUNT_CARDS: {
  key: "total" | "idle" | "busy" | "offline";
  label: string;
  tone: StatusTone;
}[] = [
  { key: "total", label: "Total Workers", tone: "neutral" },
  { key: "idle", label: "Idle", tone: "green" },
  { key: "busy", label: "Busy", tone: "yellow" },
  { key: "offline", label: "Offline", tone: "red" },
];

const TONE_CLASSES: Record<StatusTone, string> = {
  blue: "border-blue-500/30 bg-blue-500/5",
  yellow: "border-amber-500/30 bg-amber-500/5",
  green: "border-emerald-500/30 bg-emerald-500/5",
  red: "border-red-500/30 bg-red-500/5",
  neutral: "border-neutral-800 bg-neutral-900/20",
};

const TEXT_CLASSES: Record<StatusTone, string> = {
  blue: "text-blue-400",
  yellow: "text-amber-400",
  green: "text-emerald-400",
  red: "text-red-400",
  neutral: "text-neutral-300",
};

function workerTone(status: string): StatusTone {
  switch (status) {
    case "idle":
      return "green";
    case "busy":
      return "yellow";
    case "offline":
      return "red";
    default:
      return "neutral";
  }
}

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 5) return "just now";
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

function runningTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return `${diff}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ${diff % 60}s`;
  return `${Math.floor(diff / 3600)}h`;
}

function usageBar(value: number | null) {
  const clamped = value === null ? 0 : Math.max(0, Math.min(100, value));
  const color = clamped > 75 ? "bg-red-500" : clamped > 50 ? "bg-amber-500" : "bg-emerald-500";
  return { clamped, color };
}

export default function WorkersPage() {
  const router = useRouter();
  const { loading, token } = useAuth();
  const { workers } = useWorkers();
  const connectionState = useConnectionState();
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    const timer = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(timer);
  }, []);

  const counts = useMemo(() => {
    return {
      total: workers.length,
      idle: workers.filter((w) => w.status === "idle").length,
      busy: workers.filter((w) => w.status === "busy").length,
      offline: workers.filter((w) => w.status === "offline").length,
    };
  }, [workers]);

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  return (
    <DashboardShell active="workers">
      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Worker Pool</h1>
          <p className="text-sm text-neutral-400 mt-1">
            Health of the distributed execution fleet. Updates are pushed live
            over WebSockets.
          </p>
        </div>
        <span className="text-xs text-neutral-500 flex items-center gap-2">
          <span className={`inline-flex items-center gap-1.5 ${connectionState === "connected" ? "text-emerald-400" : "text-amber-400"}`}>
            <Radio className="w-3.5 h-3.5" />
            {connectionState === "connected" ? "Live" : connectionState === "connecting" ? "Connecting" : "Disconnected"}
          </span>
        </span>
      </div>

      {/* Pool summary */}
      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {COUNT_CARDS.map((card) => {
          const value = counts[card.key];
          return (
            <div
              key={card.key}
              className={`p-6 rounded-xl glass-panel ${TONE_CLASSES[card.tone]}`}
            >
              <div className="flex items-center gap-3 mb-4">
                <span className={`w-2 h-2 rounded-full ${TEXT_CLASSES[card.tone]}`} />
                <span className="text-sm text-neutral-400 font-medium">{card.label}</span>
              </div>
              <span className={`text-3xl font-bold tracking-tight tabular-nums ${TEXT_CLASSES[card.tone]}`}>
                {value}
              </span>
            </div>
          );
        })}
      </div>

      {/* Worker cards */}
      {workers.length === 0 ? (
        <div className="rounded-xl glass-panel px-5 py-12 text-center">
          <p className="text-sm text-neutral-500">
            No workers registered. Start Sidekiq and the heartbeat driver will register Worker-01…Worker-N.
          </p>
        </div>
      ) : (
        <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {workers.map((worker) => {
            const tone = workerTone(worker.status);
            const cpu = usageBar(worker.cpu_usage);
            const mem = usageBar(worker.memory_usage);
            const job = worker.current_job;
            return (
              <div
                key={worker.id}
                className={`rounded-xl glass-panel p-5 border ${
                  worker.status === "offline"
                    ? "border-red-500/30"
                    : worker.status === "busy"
                    ? "border-amber-500/30"
                    : "border-neutral-800"
                }`}
              >
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <span className="w-9 h-9 rounded-lg bg-white/5 border border-neutral-800 flex items-center justify-center">
                      <Cpu className={`w-4 h-4 ${TEXT_CLASSES[tone]}`} />
                    </span>
                    <div>
                      <p className="font-semibold tracking-tight">{worker.worker_name}</p>
                      <p className="text-xs text-neutral-500 flex items-center gap-1">
                        <Activity className="w-3 h-3" />
                        heartbeat {relativeTime(worker.heartbeat_at)}
                      </p>
                    </div>
                  </div>
                  <StatusBadge status={worker.status} pulse={worker.status === "busy"} />
                </div>

                {job ? (
                  <div className="mb-4 p-3 rounded-lg border border-neutral-900 bg-black/20">
                    <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-2 flex items-center gap-1.5">
                      <Play className="w-3 h-3 text-amber-400" /> Running Job
                    </p>
                    <div className="flex items-center justify-between text-sm mb-1.5">
                      <Link
                        href={`/test-runs/${job.test_run_id}/jobs/${job.id}`}
                        className="text-white font-medium hover:text-neutral-300 transition-colors"
                      >
                        Chunk #{job.chunk_number}
                      </Link>
                      <span className="text-neutral-400 font-mono text-xs flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {runningTime(job.started_at)}
                      </span>
                    </div>
                    <div className="text-xs text-neutral-500 font-mono flex items-center gap-1.5 truncate">
                      <Box className="w-3 h-3 shrink-0" />
                      <span className="truncate">{job.container_id ?? "—"}</span>
                    </div>
                    <p className="text-xs text-neutral-400 mt-1.5">
                      Browser: {worker.browser ?? "Chrome"} · Container: {worker.container_status ?? "—"}
                    </p>
                  </div>
                ) : (
                  <div className="mb-4 p-3 rounded-lg border border-neutral-900 bg-black/20 text-xs text-neutral-500">
                    No job assigned
                  </div>
                )}

                {/* Resource usage */}
                <div className="space-y-3">
                  <div>
                    <div className="flex items-center justify-between text-xs mb-1.5">
                      <span className="text-neutral-500 inline-flex items-center gap-1.5">
                        <Cpu className="w-3 h-3" /> CPU
                      </span>
                      <span className="text-neutral-300 tabular-nums">{worker.cpu_usage?.toFixed(1) ?? "—"}%</span>
                    </div>
                    <div className="h-1.5 rounded-full bg-neutral-900 overflow-hidden">
                      <div className={`h-full ${cpu.color}`} style={{ width: `${cpu.clamped}%` }} />
                    </div>
                  </div>
                  <div>
                    <div className="flex items-center justify-between text-xs mb-1.5">
                      <span className="text-neutral-500 inline-flex items-center gap-1.5">
                        <MemoryStick className="w-3 h-3" /> Memory
                      </span>
                      <span className="text-neutral-300 tabular-nums">{worker.memory_usage?.toFixed(1) ?? "—"}%</span>
                    </div>
                    <div className="h-1.5 rounded-full bg-neutral-900 overflow-hidden">
                      <div className={`h-full ${mem.color}`} style={{ width: `${mem.clamped}%` }} />
                    </div>
                  </div>
                </div>

                <div className="mt-4 pt-3 border-t border-neutral-900 flex items-center justify-between text-xs text-neutral-500">
                  <span className="inline-flex items-center gap-1.5">
                    <HardDrive className="w-3 h-3" />
                    {worker.execution_count} jobs executed
                  </span>
                  <span className="font-mono">#{worker.id}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </DashboardShell>
  );
}
