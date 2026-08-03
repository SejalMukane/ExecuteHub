"use client";

import React, { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Clock, Play, CheckCircle2, XCircle, Radio, RefreshCcw } from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import { api, QueueStats } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import { useConnectionState, useQueue } from "@/context/RealtimeContext";
import { QueueMetricsEvent } from "@/lib/realtime";

const TONE_CLASSES: Record<string, string> = {
  blue: "border-blue-500/30 bg-blue-500/5",
  yellow: "border-amber-500/30 bg-amber-500/5",
  green: "border-emerald-500/30 bg-emerald-500/5",
  red: "border-red-500/30 bg-red-500/5",
};

const TEXT_CLASSES: Record<string, string> = {
  blue: "text-blue-400",
  yellow: "text-amber-400",
  green: "text-emerald-400",
  red: "text-red-400",
};

export default function QueuePage() {
  const router = useRouter();
  const { token, loading } = useAuth();
  const connectionState = useConnectionState();
  const { queue: liveQueue } = useQueue();
  const [apiStats, setApiStats] = useState<QueueStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const res = await api.getQueueStats(token);
        if (!cancelled) setApiStats(res.queue);
      } catch (err) {
        if (!cancelled)
          setError(err instanceof Error ? err.message : "Failed to load queue.");
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, [token]);

  const queue: Partial<QueueMetricsEvent & QueueStats> = useMemo(() => {
    return {
      ...apiStats,
      ...liveQueue,
    };
  }, [apiStats, liveQueue]);

  const total =
    (queue.queued_jobs ?? 0) +
    (queue.running_jobs ?? 0) +
    (queue.completed_jobs ?? 0) +
    (queue.failed_jobs ?? 0);

  const cards = [
    { key: "queued_jobs", label: "Queued Jobs", icon: Clock, tone: "blue", value: queue.queued_jobs ?? queue.queue_size ?? 0 },
    { key: "running_jobs", label: "Running Jobs", icon: Play, tone: "yellow", value: queue.running_jobs ?? 0 },
    { key: "completed_jobs", label: "Completed Today", icon: CheckCircle2, tone: "green", value: queue.completed_today ?? queue.completed_jobs ?? 0 },
    { key: "failed_jobs", label: "Failed Today", icon: XCircle, tone: "red", value: queue.failed_today ?? queue.failed_jobs ?? 0 },
    { key: "retry_count", label: "Retry Queue", icon: RefreshCcw, tone: "blue", value: queue.retry_count ?? 0 },
  ];

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  return (
    <DashboardShell active="queue">
      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Queue</h1>
          <p className="text-sm text-neutral-400 mt-1">
            Live state of the <span className="text-neutral-300 font-mono">test_execution</span> queue.
          </p>
        </div>
        <span className="text-xs text-neutral-500 flex items-center gap-1.5">
          <span className={`inline-flex items-center gap-1.5 ${connectionState === "connected" ? "text-emerald-400" : "text-amber-400"}`}>
            <Radio className="w-3.5 h-3.5" />
            {connectionState === "connected" ? "Live" : connectionState === "connecting" ? "Connecting" : "Disconnected"}
          </span>
        </span>
      </div>

      {error && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      <div className="grid sm:grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
        {cards.map((card) => {
          const Icon = card.icon;
          return (
            <div
              key={card.key}
              className={`p-6 rounded-xl glass-panel ${TONE_CLASSES[card.tone]}`}
            >
              <div className="flex items-center gap-3 mb-4">
                <Icon className={`w-4 h-4 ${TEXT_CLASSES[card.tone]}`} />
                <span className="text-sm text-neutral-400 font-medium">{card.label}</span>
              </div>
              <span className={`text-3xl font-bold tracking-tight tabular-nums ${TEXT_CLASSES[card.tone]}`}>
                {card.value}
              </span>
            </div>
          );
        })}
      </div>

      <div className="grid lg:grid-cols-3 gap-6 mb-8">
        <div className="rounded-xl glass-panel p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold">Throughput</h2>
            <span className="text-xs text-neutral-500">{total} jobs tracked</span>
          </div>
          <div className="h-2 rounded-full bg-neutral-900 overflow-hidden flex">
            {total > 0 && (
              <>
                <div
                  className="h-full bg-blue-500"
                  style={{ width: `${((queue.queued_jobs ?? 0) / total) * 100}%` }}
                  title={`${queue.queued_jobs ?? 0} queued`}
                />
                <div
                  className="h-full bg-amber-500"
                  style={{ width: `${((queue.running_jobs ?? 0) / total) * 100}%` }}
                  title={`${queue.running_jobs ?? 0} running`}
                />
                <div
                  className="h-full bg-emerald-500"
                  style={{ width: `${((queue.completed_jobs ?? 0) / total) * 100}%` }}
                  title={`${queue.completed_jobs ?? 0} completed`}
                />
                <div
                  className="h-full bg-red-500"
                  style={{ width: `${((queue.failed_jobs ?? 0) / total) * 100}%` }}
                  title={`${queue.failed_jobs ?? 0} failed`}
                />
              </>
            )}
          </div>
          <div className="flex flex-wrap gap-5 mt-4 text-xs">
            <span className="inline-flex items-center gap-1.5 text-blue-400">
              <span className="w-2 h-2 rounded-full bg-blue-500" /> Queued
            </span>
            <span className="inline-flex items-center gap-1.5 text-amber-400">
              <span className="w-2 h-2 rounded-full bg-amber-500" /> Running
            </span>
            <span className="inline-flex items-center gap-1.5 text-emerald-400">
              <span className="w-2 h-2 rounded-full bg-emerald-500" /> Completed
            </span>
            <span className="inline-flex items-center gap-1.5 text-red-400">
              <span className="w-2 h-2 rounded-full bg-red-500" /> Failed
            </span>
          </div>
        </div>

        <div className="rounded-xl glass-panel p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold">Wait Metrics</h2>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 rounded-lg border border-neutral-900 bg-black/10">
              <p className="text-2xl font-bold text-neutral-200 tabular-nums">{queue.average_wait_time?.toFixed(1) ?? "—"}s</p>
              <p className="text-xs text-neutral-500 mt-1">Average Wait Time</p>
            </div>
            <div className="p-4 rounded-lg border border-neutral-900 bg-black/10">
              <p className="text-2xl font-bold text-neutral-200 tabular-nums">
                {queue.longest_waiting_job ? `${queue.longest_waiting_job.waiting_seconds.toFixed(1)}s` : "—"}
              </p>
              <p className="text-xs text-neutral-500 mt-1">Longest Waiting Job</p>
            </div>
          </div>
          {queue.longest_waiting_job && (
            <p className="mt-3 text-xs text-neutral-400 font-mono">
              Job #{queue.longest_waiting_job.job_id} waiting since {new Date(queue.longest_waiting_job.enqueued_at).toLocaleTimeString()}
            </p>
          )}
        </div>

        <div className="rounded-xl glass-panel p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold">Retry Queue</h2>
          </div>
          <div className="p-4 rounded-lg border border-neutral-900 bg-black/10">
            <p className="text-2xl font-bold text-blue-400 tabular-nums">{queue.retry_count ?? 0}</p>
            <p className="text-xs text-neutral-500 mt-1">Jobs currently waiting for retry</p>
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
