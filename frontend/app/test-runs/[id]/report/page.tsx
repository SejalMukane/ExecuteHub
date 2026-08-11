"use client";

import React, { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  Loader2,
  ArrowLeft,
  FileText,
  CheckCircle2,
  XCircle,
  SkipForward,
  Repeat,
  Clock,
  Bug,
  Radio,
} from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge, { ProgressBar } from "@/components/StatusBadge";
import { useAuth } from "@/context/AuthContext";
import { useRunProgressEvent } from "@/hooks/useTestRun";
import { api, TestReport, TestResult, TestRun } from "@/lib/api";
import { ConnectionState, subscribeTestRun } from "@/lib/realtime";

function formatDuration(ms: number | null): string {
  if (ms === null || ms === undefined) return "—";
  if (ms < 1000) return `${ms}ms`;
  const seconds = ms / 1000;
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m ${Math.round(seconds % 60)}s`;
}

export default function TestRunReportPage() {
  const params = useParams<{ id: string }>();
  const runId = Number(params.id);
  const router = useRouter();
  const { token, loading } = useAuth();

  const [run, setRun] = useState<TestRun | null>(null);
  const [report, setReport] = useState<TestReport | null>(null);
  const [results, setResults] = useState<TestResult[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [connectionState, setConnectionState] =
    useState<ConnectionState>("connecting");

  const liveRun = useRunProgressEvent(runId);

  const load = useCallback(async () => {
    if (!token) return;
    try {
      const data = await api.getTestRunReport(token, runId);
      setRun(data.test_run);
      setReport(data.test_report);
      setResults(data.test_results);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load report.");
    }
  }, [token, runId]);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!token) return;
    const sub = subscribeTestRun(
      token,
      runId,
      (message) => {
        if (message.type === "report_generated") {
          setReport(message.report as unknown as TestReport);
          load();
        } else if (message.type === "test_result_completed") {
          load();
        }
      },
      setConnectionState
    );
    return () => sub.unsubscribe();
  }, [token, runId, load]);

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const live = liveRun ?? run;
  const runStatus = live?.status ?? run?.status ?? "queued";

  const stats = [
    { label: "Total", value: report?.total_tests ?? 0, icon: FileText },
    { label: "Passed", value: report?.passed_tests ?? 0, icon: CheckCircle2, tone: "text-emerald-400" },
    { label: "Failed", value: report?.failed_tests ?? 0, icon: XCircle, tone: "text-red-400" },
    { label: "Skipped", value: report?.skipped_tests ?? 0, icon: SkipForward, tone: "text-neutral-400" },
    { label: "Flaky", value: report?.flaky_tests ?? 0, icon: Repeat, tone: "text-amber-400" },
    { label: "Duration", value: formatDuration(report?.duration_ms ?? null), icon: Clock },
  ];

  const failedResults = results.filter((r) => r.status === "failed");

  return (
    <DashboardShell active="test-runs">
      <Link
        href={`/test-runs/${runId}`}
        className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-white transition-colors mb-3"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to run #{runId}
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
          <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
            <div>
              <h1 className="text-2xl font-bold tracking-tight">
                Test Report <span className="text-neutral-600 font-normal">· Run #{run.id}</span>
              </h1>
              <p className="text-sm text-neutral-400 mt-1 flex items-center gap-3 flex-wrap">
                <span>{run.project_name}</span>
                <span className="text-neutral-600">·</span>
                <span className="font-mono text-xs">{run.branch}</span>
                <span className={`inline-flex items-center gap-1.5 text-xs ${connectionState === "connected" ? "text-emerald-400" : "text-amber-400"}`}>
                  <Radio className="w-3 h-3" />
                  {connectionState === "connected" ? "Live" : "Connecting"}
                </span>
              </p>
            </div>
            <StatusBadge status={runStatus} />
          </div>

          {!report ? (
            <div className="rounded-xl glass-panel px-5 py-12 text-center">
              <p className="text-sm text-neutral-500">
                Report not generated yet — waiting for every job to finish.
              </p>
              <div className="mt-6 max-w-md mx-auto">
                <ProgressBar value={live?.progress_percentage ?? 0} />
              </div>
            </div>
          ) : (
            <>
              <div className="rounded-xl glass-panel p-6 mb-8">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold">Success Rate</p>
                  <span className="text-sm font-bold tabular-nums text-emerald-400">
                    {report.success_rate}%
                  </span>
                </div>
                <ProgressBar value={report.success_rate} />
                <div className="mt-6 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
                  {stats.map((stat) => {
                    const Icon = stat.icon;
                    return (
                      <div key={stat.label} className="p-4 rounded-lg border border-neutral-900 bg-black/10">
                        <div className="flex items-center gap-2 mb-2">
                          <Icon className={`w-3.5 h-3.5 ${stat.tone ?? "text-neutral-500"}`} />
                          <span className="text-xs text-neutral-500 font-medium">{stat.label}</span>
                        </div>
                        <span className="text-xl font-bold tracking-tight tabular-nums">{stat.value}</span>
                      </div>
                    );
                  })}
                </div>
              </div>

              {failedResults.length > 0 && (
                <div className="rounded-xl glass-panel p-5 mb-8">
                  <div className="flex items-center justify-between mb-4">
                    <h2 className="text-sm font-semibold flex items-center gap-2">
                      <Bug className="w-4 h-4 text-red-400" />
                      Failed Tests ({failedResults.length})
                    </h2>
                  </div>
                  <div className="space-y-2">
                    {failedResults.map((result) => (
                      <Link
                        key={result.id}
                        href={`/test-runs/${runId}/results/${result.id}`}
                        className="flex items-center justify-between gap-3 rounded-lg border border-red-500/20 bg-red-500/5 px-4 py-3 hover:bg-red-500/10 transition-colors"
                      >
                        <div className="min-w-0">
                          <p className="text-sm text-white font-medium truncate">{result.test_name}</p>
                          <p className="text-xs text-neutral-500 truncate">
                            {result.suite_name ?? "—"} · {result.browser ?? "—"} ·{" "}
                            {result.error_message ?? "No error message"}
                          </p>
                        </div>
                        <div className="flex items-center gap-3 shrink-0">
                          <span className="text-xs text-neutral-500 tabular-nums">
                            {formatDuration(result.duration_ms)}
                          </span>
                          <StatusBadge status="failed" />
                        </div>
                      </Link>
                    ))}
                  </div>
                </div>
              )}

              <div className="rounded-xl glass-panel overflow-hidden">
                <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
                  <h2 className="text-sm font-semibold">Test Results</h2>
                  <span className="text-xs text-neutral-500">{results.length} tests</span>
                </div>
                {results.length === 0 ? (
                  <div className="px-5 py-12 text-center">
                    <p className="text-sm text-neutral-500">No individual test results yet.</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                          <th className="text-left px-5 py-3 font-medium">Test</th>
                          <th className="text-left px-5 py-3 font-medium">Suite</th>
                          <th className="text-left px-5 py-3 font-medium">Status</th>
                          <th className="text-left px-5 py-3 font-medium">Browser</th>
                          <th className="text-right px-5 py-3 font-medium">Duration</th>
                          <th className="text-right px-5 py-3 font-medium">Retries</th>
                        </tr>
                      </thead>
                      <tbody>
                        {results.map((result) => (
                          <tr key={result.id} className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors">
                            <td className="px-5 py-3.5">
                              {result.status === "failed" ? (
                                <Link
                                  href={`/test-runs/${runId}/results/${result.id}`}
                                  className="text-white font-medium hover:text-neutral-300 transition-colors"
                                >
                                  {result.test_name}
                                </Link>
                              ) : (
                                <span className="text-neutral-300">{result.test_name}</span>
                              )}
                            </td>
                            <td className="px-5 py-3.5 text-neutral-500">{result.suite_name ?? "—"}</td>
                            <td className="px-5 py-3.5">
                              <StatusBadge status={result.status} />
                            </td>
                            <td className="px-5 py-3.5 text-neutral-500">{result.browser ?? "—"}</td>
                            <td className="px-5 py-3.5 text-neutral-400 text-right tabular-nums">
                              {formatDuration(result.duration_ms)}
                            </td>
                            <td className="px-5 py-3.5 text-neutral-400 text-right tabular-nums">
                              {result.retry_count}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </>
          )}
        </>
      )}
    </DashboardShell>
  );
}
