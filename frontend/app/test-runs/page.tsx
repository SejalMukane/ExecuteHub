"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Loader2, Rocket, GitBranch, RefreshCw } from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge, { ProgressBar } from "@/components/StatusBadge";
import { api, TestRun } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

export default function TestRunsPage() {
  const router = useRouter();
  const { token, loading } = useAuth();
  const [runs, setRuns] = useState<TestRun[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const res = await api.listTestRuns(token);
        if (!cancelled) setRuns(res.test_runs);
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : "Failed to load test runs.");
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

  return (
    <DashboardShell active="test-runs">
      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Test Runs</h1>
          <p className="text-sm text-neutral-400 mt-1">
            Test executions scheduled across your projects. Click a run to inspect its jobs.
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

      <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 overflow-hidden">
        <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
          <h2 className="text-sm font-semibold">All Runs</h2>
          <span className="text-xs text-neutral-500">{runs.length} total</span>
        </div>

        {runs.length === 0 ? (
          <div className="px-5 py-12 text-center">
            <Rocket className="w-8 h-8 text-neutral-600 mx-auto mb-3" />
            <p className="text-sm text-neutral-500">
              No test runs yet. Open a project and click <span className="text-white font-medium">Run Test</span>.
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                  <th className="text-left px-5 py-3 font-medium">Run</th>
                  <th className="text-left px-5 py-3 font-medium">Project</th>
                  <th className="text-left px-5 py-3 font-medium">Status</th>
                  <th className="text-left px-5 py-3 font-medium">Progress</th>
                  <th className="text-left px-5 py-3 font-medium">Jobs</th>
                  <th className="text-left px-5 py-3 font-medium">Created</th>
                  <th className="text-right px-5 py-3 font-medium">Action</th>
                </tr>
              </thead>
              <tbody>
                {runs.map((run) => (
                  <tr
                    key={run.id}
                    className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors cursor-pointer"
                    onClick={() => router.push(`/test-runs/${run.id}`)}
                  >
                    <td className="px-5 py-3.5 text-white font-medium">#{run.id}</td>
                    <td className="px-5 py-3.5">
                      <span className="inline-flex items-center gap-1.5 text-neutral-300">
                        <GitBranch className="w-3.5 h-3.5 text-neutral-500" />
                        {run.project_name}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <StatusBadge
                        status={run.status}
                        pulse={run.status === "running" || run.status === "scheduling"}
                      />
                    </td>
                    <td className="px-5 py-3.5">
                      <ProgressBar value={run.progress_percentage} />
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400 tabular-nums">
                      {run.completed_jobs}/{run.total_jobs}
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400">{relativeTime(run.created_at)}</td>
                    <td className="px-5 py-3.5 text-right">
                      <Link
                        href={`/test-runs/${run.id}`}
                        className="text-neutral-500 hover:text-white transition-colors text-xs font-medium uppercase tracking-wider"
                        onClick={(e) => e.stopPropagation()}
                      >
                        Details
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </DashboardShell>
  );
}
