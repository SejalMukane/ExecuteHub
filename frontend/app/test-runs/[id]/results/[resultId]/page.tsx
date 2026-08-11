"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  Loader2,
  ArrowLeft,
  Bug,
  Terminal,
  Box,
  Globe,
  Repeat,
  Clock,
  Download,
  ScrollText,
  Images,
} from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge from "@/components/StatusBadge";
import { useAuth } from "@/context/AuthContext";
import { api, Artifact, TestResultDetail } from "@/lib/api";

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

export default function TestResultDetailPage() {
  const params = useParams<{ id: string; resultId: string }>();
  const runId = Number(params.id);
  const resultId = Number(params.resultId);
  const router = useRouter();
  const { token, loading } = useAuth();

  const [result, setResult] = useState<TestResultDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [artifactUrls, setArtifactUrls] = useState<Record<number, string>>({});

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const data = await api.getTestResult(token, resultId);
        if (!cancelled) {
          setResult(data.test_result);
          setError(null);
        }
      } catch (err) {
        if (!cancelled)
          setError(err instanceof Error ? err.message : "Failed to load test result.");
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, [token, resultId]);

  // Load screenshot/video bytes for preview (blob works for both local storage
  // and S3 — the file endpoint redirects to a signed URL).
  useEffect(() => {
    if (!token) return;
    const previews = (result?.artifacts ?? []).filter(
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
  }, [token, result?.id]);

  const downloadArtifact = async (artifact: Artifact) => {
    if (!token) return;
    try {
      const blob = await api.getArtifactFile(token, artifact.id);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = artifact.file_name ?? "download";
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      URL.revokeObjectURL(url);
    } catch {
      setError("Failed to download artifact.");
    }
  };

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  if (!result && !error) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const screenshots = result?.artifacts.filter((a) => a.artifact_type === "screenshot") ?? [];
  const videos = result?.artifacts.filter((a) => a.artifact_type === "video") ?? [];
  const otherArtifacts = result?.artifacts.filter(
    (a) => a.artifact_type !== "screenshot" && a.artifact_type !== "video"
  ) ?? [];

  return (
    <DashboardShell active="test-runs">
      <Link
        href={`/test-runs/${runId}/report`}
        className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-white transition-colors mb-3"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to report
      </Link>

      {error && !result && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      {!result ? (
        <div className="rounded-xl glass-panel px-5 py-12 text-center">
          <p className="text-sm text-neutral-500">Test result not found.</p>
        </div>
      ) : (
        <>
          <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
            <div className="min-w-0">
              <h1 className="text-2xl font-bold tracking-tight flex items-center gap-3">
                <Bug className="w-6 h-6 text-red-400 shrink-0" />
                <span className="truncate">{result.test_name}</span>
              </h1>
              <p className="text-sm text-neutral-400 mt-1 flex items-center gap-2 flex-wrap">
                <span>{result.suite_name ?? "—"}</span>
                <span className="text-neutral-600">·</span>
                <span>Run #{result.test_run_id}</span>
              </p>
            </div>
            <StatusBadge status={result.status} />
          </div>

          <div className="grid lg:grid-cols-3 gap-6 mb-8">
            <div className="lg:col-span-2 rounded-xl glass-panel p-6">
              <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-3">
                Error Message
              </p>
              <pre className="text-sm text-red-400 whitespace-pre-wrap bg-black/20 rounded-lg p-4 border border-red-500/20">
                {result.error_message ?? "No error message recorded."}
              </pre>

              {result.stack_trace && (
                <>
                  <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mt-6 mb-3">
                    Stack Trace
                  </p>
                  <pre className="text-xs text-neutral-300 whitespace-pre-wrap font-mono bg-black/20 rounded-lg p-4 overflow-x-auto">
                    {result.stack_trace}
                  </pre>
                </>
              )}
            </div>

            <div className="rounded-xl glass-panel p-6">
              <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-4">Details</p>
              <dl className="space-y-3 text-sm">
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Box className="w-3.5 h-3.5" /> Worker
                  </dt>
                  <dd className="text-neutral-200 font-mono text-xs">{result.worker ?? "—"}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Globe className="w-3.5 h-3.5" /> Browser
                  </dt>
                  <dd className="text-neutral-200">{result.browser ?? "—"}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5" /> Duration
                  </dt>
                  <dd className="text-neutral-200 tabular-nums">{formatDuration(result.duration_ms)}</dd>
                </div>
                <div className="flex items-center justify-between">
                  <dt className="text-neutral-500 flex items-center gap-1.5">
                    <Repeat className="w-3.5 h-3.5" /> Retries
                  </dt>
                  <dd className="text-neutral-200 tabular-nums">{result.retry_count}</dd>
                </div>
              </dl>
            </div>
          </div>

          {screenshots.length > 0 && (
            <div className="rounded-xl glass-panel p-5 mb-6">
              <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                <Images className="w-4 h-4 text-neutral-500" /> Screenshots
              </h3>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {screenshots.map((a) => (
                  <div key={a.id} className="rounded-lg border border-neutral-900 overflow-hidden">
                    {artifactUrls[a.id] ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={artifactUrls[a.id]}
                        alt={a.file_name}
                        className="w-full aspect-video object-contain bg-black"
                      />
                    ) : (
                      <div className="w-full aspect-video flex items-center justify-center bg-black text-xs text-neutral-600">
                        Loading…
                      </div>
                    )}
                    <div className="px-3 py-2 flex items-center justify-between text-xs">
                      <span className="text-neutral-500 truncate">{a.file_name}</span>
                      <span className="text-neutral-600 tabular-nums">{formatBytes(a.file_size)}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {videos.length > 0 && (
            <div className="rounded-xl glass-panel p-5 mb-6">
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
                      <span className="text-neutral-500 truncate">{a.file_name}</span>
                      <span className="text-neutral-600 tabular-nums">{formatBytes(a.file_size)}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {(otherArtifacts.length > 0 || (result.logs?.length ?? 0) > 0) && (
            <div className="grid lg:grid-cols-2 gap-6 mb-6">
              {otherArtifacts.length > 0 && (
                <div className="rounded-xl glass-panel p-5">
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <Download className="w-4 h-4 text-neutral-500" /> Artifacts
                  </h3>
                  <div className="space-y-2">
                    {otherArtifacts.map((a) => (
                      <div key={a.id} className="flex items-center justify-between rounded-lg border border-neutral-900 px-4 py-3">
                        <div className="min-w-0">
                          <p className="text-sm text-neutral-200 font-mono truncate">{a.file_name}</p>
                          <p className="text-xs text-neutral-500 tabular-nums">
                            {a.artifact_type} · {formatBytes(a.file_size)}
                          </p>
                        </div>
                        <button
                          onClick={() => downloadArtifact(a)}
                          className="inline-flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium bg-white/10 hover:bg-white/20 text-white transition-colors shrink-0"
                        >
                          <Download className="w-3.5 h-3.5" />
                          Download
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {result.logs && result.logs.length > 0 && (
                <div className="rounded-xl glass-panel p-5">
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <ScrollText className="w-4 h-4 text-neutral-500" /> Job Logs
                  </h3>
                  <div className="max-h-[260px] overflow-y-auto font-mono text-xs space-y-1">
                    {result.logs.map((log) => (
                      <div key={log.id} className="flex gap-3">
                        <span className="text-neutral-600 shrink-0 tabular-nums">
                          {new Date(log.timestamp).toLocaleTimeString()}
                        </span>
                        <span className="text-neutral-500 shrink-0 uppercase">{log.level}</span>
                        <span className="text-neutral-300 whitespace-pre-wrap">{log.message}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </>
      )}
    </DashboardShell>
  );
}
