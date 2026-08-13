"use client";

import React, { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Workflow, GitBranch, GitCommit } from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge from "@/components/StatusBadge";
import { api, Pipeline } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

function shortSha(sha: string | null): string {
  return sha ? sha.slice(0, 7) : "—";
}

export default function CiCdPage() {
  const router = useRouter();
  const { token, loading } = useAuth();
  const [pipelines, setPipelines] = useState<Pipeline[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const res = await api.listPipelines(token);
        if (cancelled) return;
        setPipelines(res.pipelines);
      } catch (err) {
        if (!cancelled)
          setError(err instanceof Error ? err.message : "Failed to load pipelines.");
      }
    };

    load();

    return () => {
      cancelled = true;
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
    <DashboardShell active="ci-cd">
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">CI/CD</h1>
        <p className="text-sm text-neutral-400 mt-1">
          Jenkins pipelines triggered against your projects, their builds, and release gates.
        </p>
      </div>

      {error && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      <div className="rounded-xl glass-panel overflow-hidden">
        <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
          <h2 className="text-sm font-semibold">Pipelines</h2>
          <span className="text-xs text-neutral-500">{pipelines.length} total</span>
        </div>

        {pipelines.length === 0 ? (
          <div className="px-5 py-12 text-center">
            <Workflow className="w-8 h-8 text-neutral-600 mx-auto mb-3" />
            <p className="text-sm text-neutral-500">
              No pipelines yet. Pipelines appear here when Jenkins triggers a test run.
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                  <th className="text-left px-5 py-3 font-medium">Pipeline</th>
                  <th className="text-left px-5 py-3 font-medium">Project</th>
                  <th className="text-left px-5 py-3 font-medium">Branch</th>
                  <th className="text-left px-5 py-3 font-medium">Commit</th>
                  <th className="text-left px-5 py-3 font-medium">Status</th>
                  <th className="text-left px-5 py-3 font-medium">Gate</th>
                  <th className="text-left px-5 py-3 font-medium">Builds</th>
                  <th className="text-left px-5 py-3 font-medium">Created</th>
                </tr>
              </thead>
              <tbody>
                {pipelines.map((pipeline) => (
                  <tr
                    key={pipeline.id}
                    className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors cursor-pointer"
                    onClick={() => router.push(`/ci-cd/${pipeline.id}`)}
                  >
                    <td className="px-5 py-3.5 text-white font-medium">{pipeline.name}</td>
                    <td className="px-5 py-3.5 text-neutral-300">{pipeline.project_name}</td>
                    <td className="px-5 py-3.5">
                      <span className="inline-flex items-center gap-1.5 text-neutral-300">
                        <GitBranch className="w-3.5 h-3.5 text-neutral-500" />
                        {pipeline.branch}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="inline-flex items-center gap-1.5 text-neutral-400 font-mono text-xs">
                        <GitCommit className="w-3.5 h-3.5 text-neutral-500" />
                        {shortSha(pipeline.commit_sha)}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <StatusBadge status={pipeline.status} pulse={pipeline.status === "running"} />
                    </td>
                    <td className="px-5 py-3.5">
                      <StatusBadge status={pipeline.gate_status ?? "none"} />
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400 tabular-nums">{pipeline.build_count}</td>
                    <td className="px-5 py-3.5 text-neutral-400">{relativeTime(pipeline.created_at)}</td>
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