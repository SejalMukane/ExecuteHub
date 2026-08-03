"use client";

import React from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  Loader2,
  ArrowLeft,
  GitBranch,
  GitCommit,
  Layers,
  CheckCircle2,
  XCircle,
  Clock,
  FolderKanban,
  Play,
  Radio,
} from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge, { ProgressBar, StatusTone } from "@/components/StatusBadge";
import { useAuth } from "@/context/AuthContext";
import { useTestRun } from "@/hooks/useTestRun";

function matrixTone(status: string): StatusTone {
  switch (status) {
    case "completed":
      return "green";
    case "failed":
      return "red";
    case "running":
    case "uploading_artifacts":
      return "yellow";
    case "queued":
    case "retrying":
      return "blue";
    default:
      return "neutral";
  }
}

const MATRIX_TONES: Record<StatusTone, string> = {
  blue: "bg-blue-500/15 border-blue-500/40 text-blue-400",
  yellow: "bg-amber-500/15 border-amber-500/40 text-amber-400",
  green: "bg-emerald-500/15 border-emerald-500/40 text-emerald-400",
  red: "bg-red-500/15 border-red-500/40 text-red-400",
  neutral: "bg-neutral-900 border-neutral-800 text-neutral-500",
};

function matrixClassName(job: { status: string }): string {
  const tone = matrixTone(job.status);
  return `${MATRIX_TONES[tone]} ${job.status === "running" || job.status === "uploading_artifacts" ? "animate-pulse" : ""}`;
}

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

function shortSha(sha: string | null): string {
  if (!sha) return "—";
  return sha.length > 10 ? `${sha.slice(0, 7)}…${sha.slice(-4)}` : sha;
}

export default function TestRunDetailPage() {
  const params = useParams<{ id: string }>();
  const runId = Number(params.id);
  const router = useRouter();
  const { loading, token } = useAuth();
  const { run, progress, jobs, connectionState, error } = useTestRun(runId);

  React.useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const live = progress ?? run;
  const runStatus: string = live?.status ?? run?.status ?? "queued";

  const stats = live
    ? [
        { label: "Total Tests", value: live.total_tests, icon: Layers },
        { label: "Total Jobs", value: live.total_jobs, icon: Layers },
        { label: "Running", value: live.running_jobs, icon: Play },
        { label: "Queued", value: live.queued_jobs, icon: Clock },
        { label: "Completed", value: live.completed_jobs, icon: CheckCircle2 },
        { label: "Failed", value: live.failed_jobs, icon: XCircle },
      ]
    : [];

  return (
    <DashboardShell active="test-runs">
      <Link
        href="/test-runs"
        className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-white transition-colors mb-3"
      >
        <ArrowLeft className="w-4 h-4" />
        All test runs
      </Link>

      {error && !run && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      {!run ? (
        <div className="rounded-xl glass-panel px-5 py-12 text-center">
          <p className="text-sm text-neutral-500">Test run not found.</p>
        </div>
      ) : (
        <>
          <div className="mb-8">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold tracking-tight">Test Run #{run.id}</h1>
                <p className="text-sm text-neutral-400 mt-1 flex items-center gap-3 flex-wrap">
                  <span className="inline-flex items-center gap-1.5">
                    <FolderKanban className="w-3.5 h-3.5 text-neutral-500" />
                    {run.project_name}
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <GitBranch className="w-3.5 h-3.5 text-neutral-500" />
                    {run.branch}
                  </span>
                  <span className="inline-flex items-center gap-1.5 font-mono text-xs">
                    <GitCommit className="w-3.5 h-3.5 text-neutral-500" />
                    {shortSha(run.commit_sha)}
                  </span>
                  {run.test_suite && (
                    <span className="inline-flex items-center gap-1.5">
                      <Layers className="w-3.5 h-3.5 text-neutral-500" />
                      {run.test_suite.name}
                    </span>
                  )}
                  <span className={`inline-flex items-center gap-1.5 text-xs ${connectionState === "connected" ? "text-emerald-400" : "text-amber-400"}`}>
                    <Radio className="w-3 h-3" />
                    {connectionState === "connected" ? "Live" : connectionState === "connecting" ? "Connecting" : "Disconnected"}
                  </span>
                </p>
              </div>
              <StatusBadge
                status={runStatus}
                pulse={runStatus === "running" || runStatus === "scheduling"}
              />
            </div>
          </div>

          <div className="grid lg:grid-cols-3 gap-6 mb-8">
            <div className="lg:col-span-2 rounded-xl glass-panel p-6">
              <div className="flex items-center justify-between mb-3">
                <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold">Progress</p>
                <span className="text-xs text-emerald-400 flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" /> Live · WebSocket
                </span>
              </div>
              <ProgressBar value={live?.progress_percentage ?? run.progress_percentage} />
              <div className="mt-6 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
                {stats.map((stat) => {
                  const Icon = stat.icon;
                  return (
                    <div key={stat.label} className="p-4 rounded-lg border border-neutral-900 bg-black/10">
                      <div className="flex items-center gap-2 mb-2">
                        <Icon className="w-3.5 h-3.5 text-neutral-500" />
                        <span className="text-xs text-neutral-500 font-medium">{stat.label}</span>
                      </div>
                      <span className="text-xl font-bold tracking-tight tabular-nums">{stat.value}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="rounded-xl glass-panel p-6">
              <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-4">Run Information</p>
              <dl className="space-y-3 text-sm">
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500">Run ID</dt>
                  <dd className="text-neutral-200 font-medium">#{run.id}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500">Branch</dt>
                  <dd className="text-neutral-200 font-medium">{run.branch}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500">Commit</dt>
                  <dd className="text-neutral-200 font-mono text-xs">{shortSha(run.commit_sha)}</dd>
                </div>
                {run.test_suite && (
                  <div className="flex items-center justify-between">
                    <dt className="text-neutral-500">Suite</dt>
                    <dd className="text-neutral-200 font-medium">{run.test_suite.name}</dd>
                  </div>
                )}
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500">Status</dt>
                  <dd>
                    <StatusBadge status={runStatus} />
                  </dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500">Started</dt>
                  <dd className="text-neutral-200">{relativeTime(run.started_at)}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500">Finished</dt>
                  <dd className="text-neutral-200">{relativeTime(run.finished_at)}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500">Created</dt>
                  <dd className="text-neutral-200">{relativeTime(run.created_at)}</dd>
                </div>
              </dl>
            </div>
          </div>

          <div className="rounded-xl glass-panel p-5 mb-8">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-semibold">Test Matrix</h2>
              <span className="text-xs text-neutral-500">{jobs.length} chunks</span>
            </div>

            {jobs.length === 0 ? (
              <p className="text-sm text-neutral-500">No chunks to display yet.</p>
            ) : (
              <>
                <div className="grid grid-cols-5 sm:grid-cols-10 lg:grid-cols-10 gap-1.5">
                  {jobs.map((job) => (
                    <Link
                      key={job.id}
                      href={`/test-runs/${run.id}/jobs/${job.id}`}
                      title={`Chunk #${job.chunk_number}: ${job.status}`}
                      className={`aspect-square rounded-md border flex items-center justify-center text-xs font-medium tabular-nums transition-transform hover:scale-110 ${matrixClassName(job)}`}
                    >
                      {job.chunk_number}
                    </Link>
                  ))}
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
              </>
            )}
          </div>

          <div className="rounded-xl glass-panel overflow-hidden">
            <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
              <h2 className="text-sm font-semibold">Jobs</h2>
              <span className="text-xs text-neutral-500">{jobs.length} total</span>
            </div>

            {jobs.length === 0 ? (
              <div className="px-5 py-12 text-center">
                <p className="text-sm text-neutral-500">No jobs have been created for this run yet.</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                      <th className="text-left px-5 py-3 font-medium">Chunk</th>
                      <th className="text-left px-5 py-3 font-medium">Tests</th>
                      <th className="text-left px-5 py-3 font-medium">Status</th>
                      <th className="text-left px-5 py-3 font-medium">Worker</th>
                      <th className="text-left px-5 py-3 font-medium">Retries</th>
                      <th className="text-right px-5 py-3 font-medium">Started</th>
                    </tr>
                  </thead>
                  <tbody>
                    {jobs.map((job) => (
                      <tr key={job.id} className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors">
                        <td className="px-5 py-3.5">
                          <Link
                            href={`/test-runs/${run.id}/jobs/${job.id}`}
                            className="text-white font-medium hover:text-neutral-300 transition-colors"
                          >
                            #{job.chunk_number}
                          </Link>
                        </td>
                        <td className="px-5 py-3.5 text-neutral-400 tabular-nums">{job.test_count}</td>
                        <td className="px-5 py-3.5">
                          <StatusBadge status={job.status} pulse={job.status === "running"} />
                        </td>
                        <td className="px-5 py-3.5 text-neutral-400 font-mono text-xs">{job.worker_id ?? "—"}</td>
                        <td className="px-5 py-3.5 text-neutral-400 tabular-nums">{job.retry_count}</td>
                        <td className="px-5 py-3.5 text-neutral-400 text-right">{relativeTime(job.started_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </DashboardShell>
  );
}
