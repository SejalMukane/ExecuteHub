"use client";

import React, { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Clock, Play, CheckCircle2, XCircle, RefreshCw } from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import { api, QueueStats } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

const CARDS: {
  key: keyof QueueStats;
  label: string;
  icon: typeof Clock;
  tone: "blue" | "yellow" | "green" | "red";
}[] = [
  { key: "queued_jobs", label: "Queued Jobs", icon: Clock, tone: "blue" },
  { key: "running_jobs", label: "Running Jobs", icon: Play, tone: "yellow" },
  { key: "completed_jobs", label: "Completed Jobs", icon: CheckCircle2, tone: "green" },
  { key: "failed_jobs", label: "Failed Jobs", icon: XCircle, tone: "red" },
];

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
  const [stats, setStats] = useState<QueueStats | null>(null);
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
        if (!cancelled) setStats(res.queue);
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : "Failed to load queue.");
      }
    };

    load();
    const timer = setInterval(load, 5000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [token]);

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const total =
    stats === null
      ? 0
      : stats.queued_jobs + stats.running_jobs + stats.completed_jobs + stats.failed_jobs;

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
          <RefreshCw className="w-3.5 h-3.5" /> Auto-refreshing every 5s
        </span>
      </div>

      {error && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {CARDS.map((card) => {
          const Icon = card.icon;
          const value = stats ? stats[card.key] : null;
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
                {value ?? "—"}
              </span>
            </div>
          );
        })}
      </div>

      <div className="rounded-xl glass-panel p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold">Throughput</h2>
          <span className="text-xs text-neutral-500">{total} jobs tracked</span>
        </div>
        <div className="h-2 rounded-full bg-neutral-900 overflow-hidden flex">
          {total > 0 && stats && (
            <>
              <div
                className="h-full bg-blue-500"
                style={{ width: `${(stats.queued_jobs / total) * 100}%` }}
                title={`${stats.queued_jobs} queued`}
              />
              <div
                className="h-full bg-amber-500"
                style={{ width: `${(stats.running_jobs / total) * 100}%` }}
                title={`${stats.running_jobs} running`}
              />
              <div
                className="h-full bg-emerald-500"
                style={{ width: `${(stats.completed_jobs / total) * 100}%` }}
                title={`${stats.completed_jobs} completed`}
              />
              <div
                className="h-full bg-red-500"
                style={{ width: `${(stats.failed_jobs / total) * 100}%` }}
                title={`${stats.failed_jobs} failed`}
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
    </DashboardShell>
  );
}
