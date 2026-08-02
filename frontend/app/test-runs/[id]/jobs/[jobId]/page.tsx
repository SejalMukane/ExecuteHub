"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  Loader2,
  ArrowLeft,
  Box,
  Cpu,
  MemoryStick,
  Clock,
  PlayCircle,
  CheckCircle2,
  XCircle,
  Hourglass,
  Download,
  ScrollText,
  Images,
  ListChecks,
  Activity,
} from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge, { ProgressBar } from "@/components/StatusBadge";
import { api, Artifact, ExecutionLog, JobDetail, TestRun } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

function formatDuration(ms: number | null): string {
  if (ms === null || ms === undefined) return "—";
  if (ms < 1000) return `${ms}ms`;
  const seconds = ms / 1000;
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m ${Math.round(seconds % 60)}s`;
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

type TabKey = "overview" | "logs" | "artifacts" | "summary";

const TABS: { key: TabKey; label: string; icon: typeof Box }[] = [
  { key: "overview", label: "Overview", icon: Box },
  { key: "logs", label: "Execution Logs", icon: ScrollText },
  { key: "artifacts", label: "Artifacts", icon: Images },
  { key: "summary", label: "Summary", icon: ListChecks },
];

export default function JobDetailPage() {
  const params = useParams<{ id: string; jobId: string }>();
  const runId = Number(params.id);
  const jobId = Number(params.jobId);
  const router = useRouter();
  const { token, loading } = useAuth();

  const [run, setRun] = useState<TestRun | null>(null);
  const [job, setJob] = useState<JobDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabKey>("overview");
  const [artifactUrls, setArtifactUrls] = useState<Record<number, string>>({});
  const logEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  // Auto-refresh the run + job detail every 2 seconds for live progress/logs.
  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const [runRes, jobRes] = await Promise.all([
          api.getTestRun(token, runId),
          api.getJob(token, jobId),
        ]);
        if (!cancelled) {
          setRun(runRes.test_run);
          setJob(jobRes.job);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : "Failed to load job.");
      }
    };

    load();
    const timer = setInterval(load, 2000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [token, runId, jobId]);

  // Stable signature of previewable artifacts so the loader only re-runs when
  // the set of screenshot/video ids actually changes between 2s polls.
  const previewSignature = useMemo(
    () =>
      (job?.artifacts ?? [])
        .filter((a) => a.artifact_type === "screenshot" || a.artifact_type === "video")
        .map((a) => a.id)
        .join(","),
    [job?.artifacts]
  );

  // Load screenshot/video bytes (auth via token) into object URLs for preview.
  useEffect(() => {
    if (!token) return;
    const previews = (job?.artifacts ?? []).filter(
      (a) => a.artifact_type === "screenshot" || a.artifact_type === "video"
    );
    let cancelled = false;
    const urls: Record<number, string> = {};

    (async () => {
      for (const artifact of previews) {
        try {
          const blob = await api.getArtifactFile(token, artifact.id);
          if (cancelled) break;
          urls[artifact.id] = URL.createObjectURL(blob);
        } catch {
          // skip unreadable artifacts
        }
      }
      if (!cancelled) setArtifactUrls(urls);
    })();

    return () => {
      cancelled = true;
      Object.values(urls).forEach((url) => URL.revokeObjectURL(url));
    };
    // Preview set is keyed by previewSignature (stable across polls).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, job?.id, previewSignature]);

  // Keep the newest log visible at the bottom of the stream.
  useEffect(() => {
    if (activeTab === "logs") {
      logEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [activeTab, job?.logs?.length]);

  const statusCards = useMemo(() => {
    const jobs = run?.jobs ?? [];
    return [
      {
        label: "Running",
        value: jobs.filter((j) => j.status === "running" || j.status === "uploading_artifacts").length,
        icon: PlayCircle,
        tone: "text-amber-400",
      },
      {
        label: "Completed",
        value: jobs.filter((j) => j.status === "completed").length,
        icon: CheckCircle2,
        tone: "text-emerald-400",
      },
      {
        label: "Failed",
        value: jobs.filter((j) => j.status === "failed").length,
        icon: XCircle,
        tone: "text-red-400",
      },
      {
        label: "Queued",
        value: jobs.filter((j) => j.status === "queued" || j.status === "retrying").length,
        icon: Hourglass,
        tone: "text-blue-400",
      },
    ];
  }, [run]);

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const latestLog = job?.logs && job.logs.length > 0 ? job.logs[job.logs.length - 1] : null;
  const currentTest = job
    ? job.status === "running" || job.status === "uploading_artifacts"
      ? latestLog?.message ?? "Running Playwright tests…"
      : job.status === "completed"
        ? "Execution finished"
        : job.status === "failed"
          ? "Execution failed"
          : "Awaiting execution"
    : "Loading…";

  const downloadTrace = async (artifact: Artifact) => {
    if (!token) return;
    try {
      const blob = await api.getArtifactFile(token, artifact.id);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = artifact.path.split("/").pop() ?? "trace.zip";
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      URL.revokeObjectURL(url);
    } catch {
      setError("Failed to download trace.");
    }
  };

  return (
    <DashboardShell active="test-runs">
      <Link
        href={`/test-runs/${runId}`}
        className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-white transition-colors mb-3"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to run #{runId}
      </Link>

      {error && !job && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      {!job ? (
        <div className="rounded-xl glass-panel px-5 py-12 text-center">
          <p className="text-sm text-neutral-500">Job not found.</p>
        </div>
      ) : (
        <>
          {/* Header */}
          <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
            <div>
              <h1 className="text-2xl font-bold tracking-tight">
                Job #{job.id} <span className="text-neutral-600 font-normal">· chunk {job.chunk_number}</span>
              </h1>
              <p className="text-sm text-neutral-400 mt-1 flex items-center gap-2 flex-wrap">
                <span className="inline-flex items-center gap-1.5">
                  <Activity className="w-3.5 h-3.5 text-neutral-500" />
                  {run?.project_name ?? "Test Run #" + runId}
                </span>
                <span className="text-neutral-600">·</span>
                <span>{job.test_count} tests</span>
              </p>
            </div>
            <StatusBadge
              status={job.status}
              pulse={job.status === "running" || job.status === "uploading_artifacts"}
            />
          </div>

          {/* Progress + status cards */}
          <div className="grid lg:grid-cols-3 gap-6 mb-8">
            <div className="lg:col-span-2 rounded-xl glass-panel p-6">
              <div className="flex items-center justify-between mb-3">
                <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold">Run Progress</p>
                <span className="text-xs text-neutral-500">Auto-refreshing every 2s</span>
              </div>
              <ProgressBar value={run?.progress_percentage ?? 0} />
              <div className="mt-6 grid grid-cols-2 sm:grid-cols-4 gap-3">
                {statusCards.map((card) => {
                  const Icon = card.icon;
                  return (
                    <div key={card.label} className="p-4 rounded-lg border border-neutral-900 bg-black/10">
                      <div className="flex items-center gap-2 mb-2">
                        <Icon className={`w-3.5 h-3.5 ${card.tone}`} />
                        <span className="text-xs text-neutral-500 font-medium">{card.label}</span>
                      </div>
                      <span className="text-xl font-bold tracking-tight tabular-nums">{card.value}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Worker card */}
            <div className="rounded-xl glass-panel p-6">
              <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-4">Worker</p>
              <dl className="space-y-3 text-sm">
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Box className="w-3.5 h-3.5" /> Worker Name
                  </dt>
                  <dd className="text-neutral-200 font-mono text-xs">{job.worker_id ?? "—"}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Box className="w-3.5 h-3.5" /> Container ID
                  </dt>
                  <dd className="text-neutral-200 font-mono text-xs">
                    {job.container_id ? job.container_id.slice(0, 12) + "…" : "—"}
                  </dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Activity className="w-3.5 h-3.5" /> Current Test
                  </dt>
                  <dd className="text-neutral-200 max-w-[180px] truncate">{currentTest}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5" /> Started
                  </dt>
                  <dd className="text-neutral-200">{relativeTime(job.started_at)}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5" /> Duration
                  </dt>
                  <dd className="text-neutral-200 tabular-nums">{formatDuration(job.duration_ms)}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Cpu className="w-3.5 h-3.5" /> CPU
                  </dt>
                  <dd className="text-neutral-500">—</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <MemoryStick className="w-3.5 h-3.5" /> Memory
                  </dt>
                  <dd className="text-neutral-500">—</dd>
                </div>
              </dl>
            </div>
          </div>

          {/* Tabs */}
          <div className="flex gap-1 border-b border-neutral-900 mb-6">
            {TABS.map((tab) => {
              const Icon = tab.icon;
              const active = activeTab === tab.key;
              return (
                <button
                  key={tab.key}
                  onClick={() => setActiveTab(tab.key)}
                  className={`inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors ${
                    active
                      ? "border-white text-white"
                      : "border-transparent text-neutral-500 hover:text-white"
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  {tab.label}
                </button>
              );
            })}
          </div>

          {activeTab === "overview" && <OverviewTab job={job} run={run} />}
          {activeTab === "logs" && (
            <LogsTab logs={job.logs ?? []} logEndRef={logEndRef} />
          )}
          {activeTab === "artifacts" && (
            <ArtifactsTab
              artifacts={job.artifacts ?? []}
              artifactUrls={artifactUrls}
              onDownloadTrace={downloadTrace}
            />
          )}
          {activeTab === "summary" && <SummaryTab job={job} />}
        </>
      )}
    </DashboardShell>
  );
}

function OverviewTab({ job, run }: { job: JobDetail; run: TestRun | null }) {
  const rows = [
    { label: "Job ID", value: `#${job.id}` },
    { label: "Chunk", value: `#${job.chunk_number}` },
    { label: "Tests in chunk", value: String(job.test_count) },
    { label: "Status", value: job.status },
    { label: "Worker", value: job.worker_id ?? "—" },
    { label: "Container", value: job.container_id ?? "—" },
    { label: "Passed tests", value: String(job.passed_tests) },
    { label: "Failed tests", value: String(job.failed_tests) },
    { label: "Duration", value: formatDuration(job.duration_ms) },
    { label: "Started", value: relativeTime(job.started_at) },
    { label: "Finished", value: relativeTime(job.finished_at) },
    { label: "Retries", value: String(job.retry_count) },
    { label: "Branch", value: run?.branch ?? "—" },
    { label: "Commit", value: run?.commit_sha ? run.commit_sha.slice(0, 7) : "—" },
  ];
  return (
    <div className="rounded-xl glass-panel overflow-hidden">
      <div className="px-5 py-4 border-b border-neutral-900">
        <h2 className="text-sm font-semibold">Execution Overview</h2>
      </div>
      <div className="grid sm:grid-cols-2 divide-x divide-y divide-neutral-900/60">
        {rows.map((row) => (
          <div key={row.label} className="flex items-center justify-between px-5 py-3 text-sm">
            <dt className="text-neutral-500">{row.label}</dt>
            <dd className="text-neutral-200 font-medium">{row.value}</dd>
          </div>
        ))}
      </div>
      {job.error_message && (
        <div className="px-5 py-4 border-t border-neutral-900">
          <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-2">Error</p>
          <pre className="text-sm text-red-400 whitespace-pre-wrap">{job.error_message}</pre>
        </div>
      )}
    </div>
  );
}

function LogsTab({
  logs,
  logEndRef,
}: {
  logs: ExecutionLog[];
  logEndRef: React.RefObject<HTMLDivElement | null>;
}) {
  const levelClasses: Record<string, string> = {
    info: "text-neutral-300",
    warn: "text-amber-300",
    error: "text-red-400",
  };

  return (
    <div className="rounded-xl glass-panel overflow-hidden">
      <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
        <h2 className="text-sm font-semibold">Execution Logs</h2>
        <span className="text-xs text-neutral-500">{logs.length} lines · streaming</span>
      </div>
      {logs.length === 0 ? (
        <div className="px-5 py-12 text-center">
          <p className="text-sm text-neutral-500">No logs yet — waiting for execution to start…</p>
        </div>
      ) : (
        <div className="max-h-[520px] overflow-y-auto px-5 py-4 font-mono text-xs space-y-1">
          {logs.map((log) => (
            <div key={log.id} className="flex gap-3">
              <span className="text-neutral-600 shrink-0 tabular-nums">
                {new Date(log.timestamp).toLocaleTimeString()}
              </span>
              <span
                className={`shrink-0 uppercase tracking-wider ${levelClasses[log.level] ?? "text-neutral-500"}`}
              >
                [{log.level}]
              </span>
              <span className={`whitespace-pre-wrap ${levelClasses[log.level] ?? "text-neutral-300"}`}>
                {log.message}
              </span>
            </div>
          ))}
          <div ref={logEndRef} />
        </div>
      )}
    </div>
  );
}

function ArtifactsTab({
  artifacts,
  artifactUrls,
  onDownloadTrace,
}: {
  artifacts: Artifact[];
  artifactUrls: Record<number, string>;
  onDownloadTrace: (artifact: Artifact) => void;
}) {
  const screenshots = artifacts.filter((a) => a.artifact_type === "screenshot");
  const videos = artifacts.filter((a) => a.artifact_type === "video");
  const traces = artifacts.filter((a) => a.artifact_type === "trace");

  if (artifacts.length === 0) {
    return (
      <div className="rounded-xl glass-panel px-5 py-12 text-center">
        <p className="text-sm text-neutral-500">No artifacts captured yet.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {screenshots.length > 0 && (
        <div className="rounded-xl glass-panel p-5">
          <h3 className="text-sm font-semibold mb-4">Screenshots</h3>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {screenshots.map((a) => (
              <div key={a.id} className="rounded-lg border border-neutral-900 overflow-hidden">
                {artifactUrls[a.id] ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={artifactUrls[a.id]}
                    alt={a.path}
                    className="w-full aspect-video object-contain bg-black"
                  />
                ) : (
                  <div className="w-full aspect-video flex items-center justify-center bg-black text-xs text-neutral-600">
                    Loading…
                  </div>
                )}
                <div className="px-3 py-2 flex items-center justify-between text-xs">
                  <span className="text-neutral-500 truncate">{a.path.split("/").pop()}</span>
                  <span className="text-neutral-600 tabular-nums">{formatBytes(a.size)}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {videos.length > 0 && (
        <div className="rounded-xl glass-panel p-5">
          <h3 className="text-sm font-semibold mb-4">Videos</h3>
          <div className="grid gap-4 sm:grid-cols-2">
            {videos.map((a) => (
              <div key={a.id} className="rounded-lg border border-neutral-900 overflow-hidden">
                {artifactUrls[a.id] ? (
                  <video src={artifactUrls[a.id]} controls className="w-full aspect-video bg-black" />
                ) : (
                  <div className="w-full aspect-video flex items-center justify-center bg-black text-xs text-neutral-600">
                    Loading…
                  </div>
                )}
                <div className="px-3 py-2 flex items-center justify-between text-xs">
                  <span className="text-neutral-500 truncate">{a.path.split("/").pop()}</span>
                  <span className="text-neutral-600 tabular-nums">{formatBytes(a.size)}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {traces.length > 0 && (
        <div className="rounded-xl glass-panel p-5">
          <h3 className="text-sm font-semibold mb-4">Traces</h3>
          <div className="space-y-2">
            {traces.map((a) => (
              <div
                key={a.id}
                className="flex items-center justify-between rounded-lg border border-neutral-900 px-4 py-3"
              >
                <div>
                  <p className="text-sm text-neutral-200 font-mono">{a.path.split("/").pop()}</p>
                  <p className="text-xs text-neutral-500 tabular-nums">{formatBytes(a.size)}</p>
                </div>
                <button
                  onClick={() => onDownloadTrace(a)}
                  className="inline-flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium bg-white/10 hover:bg-white/20 text-white transition-colors"
                >
                  <Download className="w-3.5 h-3.5" />
                  Download trace
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function SummaryTab({ job }: { job: JobDetail }) {
  const summary = job.summary;
  return (
    <div className="rounded-xl glass-panel overflow-hidden">
      <div className="px-5 py-4 border-b border-neutral-900">
        <h2 className="text-sm font-semibold">Execution Summary</h2>
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-px bg-neutral-900/60">
        <SummaryStat label="Passed" value={summary?.passed ?? job.passed_tests} tone="text-emerald-400" />
        <SummaryStat label="Failed" value={summary?.failed ?? job.failed_tests} tone="text-red-400" />
        <SummaryStat label="Duration" value={formatDuration(summary?.duration_ms ?? job.duration_ms)} tone="text-neutral-200" />
        <SummaryStat label="Status" value={summary?.exit_status ?? job.status} tone="text-neutral-200" />
      </div>
    </div>
  );
}

function SummaryStat({ label, value, tone }: { label: string; value: string | number; tone: string }) {
  return (
    <div className="bg-white/5 px-5 py-5">
      <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-2">{label}</p>
      <span className={`text-xl font-bold tracking-tight tabular-nums ${tone}`}>{value}</span>
    </div>
  );
}
