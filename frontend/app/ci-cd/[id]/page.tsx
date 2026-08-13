"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  Loader2,
  ArrowLeft,
  Workflow,
  GitBranch,
  GitCommit,
  ShieldCheck,
  ShieldX,
  Clock,
  Check,
  X,
} from "lucide-react";
import { toast } from "sonner";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge from "@/components/StatusBadge";
import {
  api,
  Build,
  PipelineDetailResponse,
  TestRun,
} from "@/lib/api";
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

export default function PipelineDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { token, loading } = useAuth();
  const pipelineId = Number(params.id);

  const [data, setData] = useState<PipelineDetailResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<boolean>(false);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token || !pipelineId) return;
    let cancelled = false;

    const load = async () => {
      try {
        const res = await api.getPipeline(token, pipelineId);
        if (cancelled) return;
        setData(res);
      } catch (err) {
        if (!cancelled)
          setError(err instanceof Error ? err.message : "Failed to load pipeline.");
      }
    };

    load();

    return () => {
      cancelled = true;
    };
  }, [token, pipelineId]);

  const decide = async (action: "approve" | "reject") => {
    if (!token || !data?.deployment_gate) return;
    setBusy(true);
    try {
      const res =
        action === "approve"
          ? await api.approveDeploymentGate(token, data.deployment_gate.id)
          : await api.rejectDeploymentGate(token, data.deployment_gate.id);
      setData({
        ...data,
        deployment_gate: res.deployment_gate,
        pipeline: { ...data.pipeline, status: res.deployment_gate.status === "approved" ? "passed" : "blocked" },
      });
      toast.success(
        action === "approve" ? "Release gate approved" : "Release gate rejected"
      );
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to update the gate");
    } finally {
      setBusy(false);
    }
  };

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  if (error) {
    return (
      <DashboardShell active="ci-cd">
        <div className="px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      </DashboardShell>
    );
  }

  if (!data) {
    return (
      <DashboardShell active="ci-cd">
        <div className="px-5 py-12 text-center">
          <Workflow className="w-8 h-8 text-neutral-600 mx-auto mb-3" />
          <p className="text-sm text-neutral-500">Pipeline not found.</p>
        </div>
      </DashboardShell>
    );
  }

  const gate = data.deployment_gate;
  const latestRun = data.test_runs[0];

  return (
    <DashboardShell active="ci-cd">
      <Link
        href="/ci-cd"
        className="inline-flex items-center gap-2 text-neutral-500 hover:text-white transition-colors text-xs font-medium uppercase tracking-wider mb-6"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to CI/CD
      </Link>

      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">{data.pipeline.name}</h1>
          <p className="text-sm text-neutral-400 mt-1 flex items-center gap-2">
            <span>{data.pipeline.project_name}</span>
            <span className="text-neutral-600">•</span>
            <span className="inline-flex items-center gap-1">
              <GitBranch className="w-3.5 h-3.5" /> {data.pipeline.branch}
            </span>
            <span className="text-neutral-600">•</span>
            <span className="inline-flex items-center gap-1 font-mono">
              <GitCommit className="w-3.5 h-3.5" /> {shortSha(data.pipeline.commit_sha)}
            </span>
          </p>
        </div>
        <StatusBadge status={data.pipeline.status} pulse={data.pipeline.status === "running"} />
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Pipeline timeline + builds */}
        <div className="lg:col-span-2 rounded-xl glass-panel overflow-hidden">
          <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
            <h2 className="text-sm font-semibold">Jenkins Builds</h2>
            <span className="text-xs text-neutral-500">{data.builds.length} total</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                  <th className="text-left px-5 py-3 font-medium">Build</th>
                  <th className="text-left px-5 py-3 font-medium">Status</th>
                  <th className="text-left px-5 py-3 font-medium">Started</th>
                  <th className="text-left px-5 py-3 font-medium">Duration</th>
                </tr>
              </thead>
              <tbody>
                {data.builds.map((build: Build) => (
                  <tr key={build.id} className="border-b border-neutral-900/50">
                    <td className="px-5 py-3.5">
                      <span className="text-white font-medium">#{build.jenkins_build_number}</span>
                      <span className="block text-xs text-neutral-500">{build.jenkins_job_name}</span>
                    </td>
                    <td className="px-5 py-3.5">
                      <StatusBadge status={build.status} pulse={build.status === "running"} />
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400">{relativeTime(build.started_at)}</td>
                    <td className="px-5 py-3.5 text-neutral-400 tabular-nums">
                      {build.duration_seconds ? `${build.duration_seconds}s` : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="px-5 py-4 border-t border-neutral-900">
            <h2 className="text-sm font-semibold mb-3">Test Runs</h2>
            {data.test_runs.length === 0 ? (
              <p className="text-sm text-neutral-500">No test runs recorded for this pipeline.</p>
            ) : (
              <div className="space-y-2">
                {data.test_runs.map((run: TestRun) => (
                  <div
                    key={run.id}
                    className="flex items-center justify-between px-4 py-3 rounded-lg bg-white/[0.03] hover:bg-white/[0.06] transition-colors cursor-pointer"
                    onClick={() => router.push(`/test-runs/${run.id}`)}
                  >
                    <div>
                      <span className="text-white font-medium text-sm">Test Run #{run.id}</span>
                      <span className="ml-3 text-xs text-neutral-500 tabular-nums">
                        {run.passed_tests} passed · {run.failed_tests} failed
                      </span>
                    </div>
                    <StatusBadge status={run.status} pulse={run.status === "running" || run.status === "queued"} />
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Release gate card */}
        <div className="rounded-xl glass-panel p-6 h-fit">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold">Release Gate</h2>
            {gate && (
              <StatusBadge
                status={gate.status}
                pulse={gate.status === "pending"}
              />
            )}
          </div>

          {!gate ? (
            <div className="text-sm text-neutral-500 flex items-center gap-2">
              <Clock className="w-4 h-4" />
              Waiting for a test run to complete before the gate is evaluated.
            </div>
          ) : gate.status === "approved" ? (
            <div className="flex items-start gap-3 text-sm">
              <ShieldCheck className="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" />
              <div>
                <p className="text-white font-medium">Approved for release</p>
                {gate.decided_at && (
                  <p className="text-neutral-400 text-xs mt-1">{relativeTime(gate.decided_at)}</p>
                )}
              </div>
            </div>
          ) : gate.status === "blocked" ? (
            <div className="flex items-start gap-3 text-sm">
              <ShieldX className="w-5 h-5 text-red-400 shrink-0 mt-0.5" />
              <div>
                <p className="text-white font-medium">Release blocked</p>
                {gate.reason && <p className="text-neutral-400 text-xs mt-1">{gate.reason}</p>}
              </div>
            </div>
          ) : gate.status === "pending" ? (
            <div className="space-y-4">
              <p className="text-sm text-neutral-400 flex items-center gap-2">
                <Clock className="w-4 h-4 text-amber-400" />
                Tests passed; awaiting approval to release.
              </p>
              {gate.requires_approval ? (
                <div className="flex gap-3">
                  <button
                    onClick={() => decide("approve")}
                    disabled={busy}
                    className="flex-1 inline-flex items-center justify-center gap-2 rounded-md bg-emerald-500 text-black text-sm font-medium py-2 hover:bg-emerald-400 disabled:opacity-50 transition-colors"
                  >
                    <Check className="w-4 h-4" />
                    Approve
                  </button>
                  <button
                    onClick={() => decide("reject")}
                    disabled={busy}
                    className="flex-1 inline-flex items-center justify-center gap-2 rounded-md bg-white/10 text-white text-sm font-medium py-2 hover:bg-white/20 disabled:opacity-50 transition-colors"
                  >
                    <X className="w-4 h-4" />
                    Reject
                  </button>
                </div>
              ) : (
                <p className="text-xs text-neutral-500">
                  This gate auto-approves when its tests pass.
                </p>
              )}
            </div>
          ) : (
            <div className="text-sm text-neutral-500 flex items-center gap-2">
              <Clock className="w-4 h-4" />
              Gate status: {gate.status}
            </div>
          )}

          {latestRun && (
            <div className="mt-6 pt-5 border-t border-neutral-900">
              <p className="text-xs text-neutral-500 uppercase tracking-wider mb-2">Latest run</p>
              <p className="text-sm text-neutral-300">
                #{latestRun.id} · <StatusBadge status={latestRun.status} />
              </p>
            </div>
          )}
        </div>
      </div>
    </DashboardShell>
  );
}