"use client";

import React, { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Loader2, FolderKanban, Download, RefreshCw, Trash2, Image as ImageIcon } from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge from "@/components/StatusBadge";
import { useAuth } from "@/context/AuthContext";
import { api, Artifact, ArtifactType } from "@/lib/api";

const TYPE_LABELS: Record<ArtifactType, string> = {
  screenshot: "Screenshot",
  video: "Video",
  trace: "Trace",
  log: "Log",
  report: "Report",
};

const TYPE_ICONS: Record<ArtifactType, string> = {
  screenshot: "🖼️",
  video: "🎬",
  trace: "🗺️",
  log: "📜",
  report: "📊",
};

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function relativeTime(iso: string): string {
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

export default function ArtifactsPage() {
  const router = useRouter();
  const { token, loading } = useAuth();
  const [artifacts, setArtifacts] = useState<Artifact[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loadingList, setLoadingList] = useState(true);
  const [typeFilter, setTypeFilter] = useState<ArtifactType | "all">("all");

  const load = async () => {
    if (!token) return;
    try {
      const res = await api.listArtifacts(token);
      setArtifacts(res.artifacts);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load artifacts.");
    } finally {
      setLoadingList(false);
    }
  };

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    load();
  }, [token]);

  const filtered = useMemo(
    () => (typeFilter === "all" ? artifacts : artifacts.filter((a) => a.artifact_type === typeFilter)),
    [artifacts, typeFilter]
  );

  const counts = useMemo(() => {
    const byType: Record<string, number> = {};
    artifacts.forEach((a) => {
      byType[a.artifact_type] = (byType[a.artifact_type] ?? 0) + 1;
    });
    return byType;
  }, [artifacts]);

  const handleDelete = async (id: number) => {
    if (!token) return;
    try {
      await api.deleteArtifact(token, id);
      setArtifacts((prev) => prev.filter((a) => a.id !== id));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete artifact.");
    }
  };

  const handleRetry = async (id: number) => {
    if (!token) return;
    try {
      await api.retryArtifact(token, id);
      load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to retry artifact.");
    }
  };

  const handleDownload = async (artifact: Artifact) => {
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
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to download artifact.");
    }
  };

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  return (
    <DashboardShell active="artifacts">
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight flex items-center gap-3">
          <ImageIcon className="w-6 h-6 text-neutral-500" />
          Artifacts
        </h1>
        <p className="text-sm text-neutral-400 mt-1">
          Screenshots, videos, traces, logs and reports captured during test runs.
        </p>
      </div>

      {error && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      <div className="mb-6 flex flex-wrap items-center gap-2">
        {(["all", ...(Object.keys(TYPE_LABELS) as ArtifactType[])] as const).map((type) => (
          <button
            key={type}
            onClick={() => setTypeFilter(type)}
            className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              typeFilter === type
                ? "bg-white text-black"
                : "bg-neutral-900 text-neutral-400 hover:text-white border border-neutral-800"
            }`}
          >
            {type === "all" ? "All" : `${TYPE_ICONS[type]} ${TYPE_LABELS[type]}`}
            {type !== "all" && counts[type] ? (
              <span className={typeFilter === type ? "text-black/50" : "text-neutral-600"}>
                {counts[type]}
              </span>
            ) : null}
          </button>
        ))}
      </div>

      <div className="rounded-xl glass-panel overflow-hidden">
        <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
          <h2 className="text-sm font-semibold">Recent Artifacts</h2>
          <span className="text-xs text-neutral-500">{filtered.length} total</span>
        </div>

        {loadingList ? (
          <div className="px-5 py-12 text-center">
            <Loader2 className="w-6 h-6 animate-spin text-neutral-600 mx-auto mb-3" />
            <p className="text-sm text-neutral-500">Loading artifacts…</p>
          </div>
        ) : filtered.length === 0 ? (
          <div className="px-5 py-12 text-center">
            <FolderKanban className="w-8 h-8 text-neutral-600 mx-auto mb-3" />
            <p className="text-sm text-neutral-500">No artifacts yet.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                  <th className="text-left px-5 py-3 font-medium">Type</th>
                  <th className="text-left px-5 py-3 font-medium">File</th>
                  <th className="text-left px-5 py-3 font-medium">Size</th>
                  <th className="text-left px-5 py-3 font-medium">Storage</th>
                  <th className="text-left px-5 py-3 font-medium">Status</th>
                  <th className="text-left px-5 py-3 font-medium">Created</th>
                  <th className="text-right px-5 py-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((artifact) => (
                  <tr
                    key={artifact.id}
                    className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors"
                  >
                    <td className="px-5 py-3.5">
                      <span className="text-sm">
                        {TYPE_ICONS[artifact.artifact_type]} {TYPE_LABELS[artifact.artifact_type]}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <Link
                        href={`/artifacts/${artifact.id}`}
                        className="text-white font-medium hover:text-blue-400 transition-colors font-mono text-xs"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {artifact.file_name}
                      </Link>
                      <div className="text-xs text-neutral-500 mt-0.5">
                        Run #{artifact.test_run_id} · Job #{artifact.job_id}
                      </div>
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400 tabular-nums">
                      {formatBytes(artifact.file_size)}
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="inline-flex items-center gap-1.5 text-xs text-neutral-400">
                        {artifact.storage_backend === "s3" ? "☁️ S3" : "💾 Local"}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <StatusBadge status={artifact.status} />
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400">
                      {relativeTime(artifact.created_at)}
                    </td>
                    <td className="px-5 py-3.5 text-right">
                      <div className="inline-flex items-center gap-1">
                        <Link
                          href={`/artifacts/${artifact.id}`}
                          className="text-neutral-500 hover:text-white transition-colors text-xs font-medium uppercase tracking-wider px-2 py-1"
                        >
                          View
                        </Link>
                        <button
                          onClick={() => handleDownload(artifact)}
                          className="text-neutral-500 hover:text-white transition-colors p-1"
                          title="Download"
                        >
                          <Download className="w-4 h-4" />
                        </button>
                        {artifact.status === "failed" && (
                          <button
                            onClick={() => handleRetry(artifact.id)}
                            className="text-neutral-500 hover:text-white transition-colors p-1"
                            title="Retry upload"
                          >
                            <RefreshCw className="w-4 h-4" />
                          </button>
                        )}
                        <button
                          onClick={() => handleDelete(artifact.id)}
                          className="text-neutral-500 hover:text-red-400 transition-colors p-1"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
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
