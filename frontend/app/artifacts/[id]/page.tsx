"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { Loader2, ArrowLeft, Download, Image as ImageIcon, Film, ScrollText, Waypoints, FileText } from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge from "@/components/StatusBadge";
import { useAuth } from "@/context/AuthContext";
import { api, Artifact } from "@/lib/api";

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

const TYPE_ICONS = {
  screenshot: ImageIcon,
  video: Film,
  log: ScrollText,
  trace: Waypoints,
  report: FileText,
};

export default function ArtifactViewerPage() {
  const params = useParams<{ id: string }>();
  const artifactId = Number(params.id);
  const router = useRouter();
  const { token, loading } = useAuth();

  const [artifact, setArtifact] = useState<Artifact | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [missing, setMissing] = useState(false);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const res = await api.getArtifact(token, artifactId);
        if (cancelled) return;
        setArtifact(res.artifact);

        const urlRes = await api.getArtifactUrl(token, artifactId);
        if (cancelled) return;
        if (urlRes.url) {
          setUrl(urlRes.url);
        } else if (res.artifact.artifact_type === "screenshot" || res.artifact.artifact_type === "video") {
          // Local storage — the file endpoint redirects to the on-disk file.
          const blob = await api.getArtifactFile(token, artifactId);
          if (!cancelled) setUrl(URL.createObjectURL(blob));
        }
      } catch (err) {
        if (!cancelled) {
          if (err instanceof Error && /not found|404/i.test(err.message)) {
            setMissing(true);
          } else {
            setError(err instanceof Error ? err.message : "Failed to load artifact.");
          }
        }
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, [token, artifactId]);

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  if (missing) {
    return (
      <DashboardShell active="artifacts">
        <Link href="/artifacts" className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-white transition-colors mb-3">
          <ArrowLeft className="w-4 h-4" />
          Back to artifacts
        </Link>
        <div className="rounded-xl glass-panel px-5 py-12 text-center">
          <p className="text-sm text-neutral-500">Artifact not found.</p>
        </div>
      </DashboardShell>
    );
  }

  if (!artifact) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const Icon = TYPE_ICONS[artifact.artifact_type] ?? FileText;

  const download = () => {
    if (url) {
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = artifact.file_name;
      anchor.target = "_blank";
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
    }
  };

  return (
    <DashboardShell active="artifacts">
      <Link href="/artifacts" className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-white transition-colors mb-3">
        <ArrowLeft className="w-4 h-4" />
        Back to artifacts
      </Link>

      {error && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight flex items-center gap-3">
            <Icon className="w-6 h-6 text-neutral-500 shrink-0" />
            <span className="font-mono text-lg truncate">{artifact.file_name}</span>
          </h1>
          <p className="text-sm text-neutral-400 mt-1">
            {artifact.artifact_type} · {formatBytes(artifact.file_size)} ·{" "}
            {artifact.storage_backend === "s3" ? "S3" : "Local storage"}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <StatusBadge status={artifact.status} />
          <Link
            href={`/test-runs/${artifact.test_run_id}`}
            className="text-neutral-500 hover:text-white transition-colors text-xs font-medium uppercase tracking-wider"
          >
            Run #{artifact.test_run_id}
          </Link>
          <button
            onClick={download}
            className="inline-flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium bg-white/10 hover:bg-white/20 text-white transition-colors"
          >
            <Download className="w-3.5 h-3.5" />
            Download
          </button>
        </div>
      </div>

      <div className="rounded-xl glass-panel overflow-hidden">
        {url ? (
          artifact.artifact_type === "screenshot" ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={url} alt={artifact.file_name} className="w-full object-contain bg-black" />
          ) : artifact.artifact_type === "video" ? (
            <video src={url} controls className="w-full bg-black" />
          ) : (
            <iframe src={url} className="w-full h-[70vh] bg-black" title={artifact.file_name} />
          )
        ) : (
          <div className="px-5 py-12 text-center">
            <p className="text-sm text-neutral-500">
              {artifact.status === "failed"
                ? "This artifact failed to upload and is unavailable."
                : "Loading file…"}
            </p>
          </div>
        )}
      </div>

      <dl className="mt-6 rounded-xl glass-panel p-5 grid sm:grid-cols-2 gap-4 text-sm">
        <div>
          <dt className="text-neutral-500 text-xs uppercase tracking-wider font-semibold mb-1">Job</dt>
          <dd className="text-neutral-200">#{artifact.job_id}</dd>
        </div>
        <div>
          <dt className="text-neutral-500 text-xs uppercase tracking-wider font-semibold mb-1">Content Type</dt>
          <dd className="text-neutral-200 font-mono text-xs">{artifact.content_type}</dd>
        </div>
        <div>
          <dt className="text-neutral-500 text-xs uppercase tracking-wider font-semibold mb-1">Storage Key</dt>
          <dd className="text-neutral-200 font-mono text-xs break-all">{artifact.s3_key}</dd>
        </div>
        <div>
          <dt className="text-neutral-500 text-xs uppercase tracking-wider font-semibold mb-1">Checksum</dt>
          <dd className="text-neutral-200 font-mono text-xs">{artifact.checksum ?? "—"}</dd>
        </div>
      </dl>
    </DashboardShell>
  );
}
