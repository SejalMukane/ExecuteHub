"use client";

import React, { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Activity,
  Globe,
  Box,
  LogOut,
  Play,
  Square,
  Loader2,
  Trash2,
  FolderKanban,
  Rocket,
  Timer,
  Wrench,
  CheckCircle2,
  Database,
  ShieldCheck,
  Cpu,
  Zap,
  TrendingUp,
  BarChart3,
  Clock,
} from "lucide-react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
} from "recharts";
import { api, BrowserImage, BrowserSession, Project } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import { useDashboard } from "@/context/RealtimeContext";
import DashboardShell from "@/components/DashboardShell";
import StatusBadge, { ProgressBar } from "@/components/StatusBadge";
import { avatarUrl, getInitials, readAvatarStyle } from "@/lib/avatar";

function formatElapsed(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  const remaining = s % 60;
  return `${String(m).padStart(2, "0")}:${String(remaining).padStart(2, "0")}`;
}

function formatDuration(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  const remaining = s % 60;
  const h = Math.floor(m / 60);
  if (h > 0) return `${h}h ${m % 60}m ${remaining}s`;
  if (m > 0) return `${m}m ${remaining}s`;
  return `${remaining}s`;
}

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

function workerTone(status: string) {
  switch (status) {
    case "busy":
      return "yellow";
    case "idle":
      return "green";
    case "offline":
      return "red";
    default:
      return "neutral";
  }
}

const TONE_TEXT: Record<string, string> = {
  green: "text-emerald-400",
  yellow: "text-amber-400",
  red: "text-red-400",
  blue: "text-blue-400",
  neutral: "text-neutral-400",
};

const TONE_BG: Record<string, string> = {
  green: "bg-emerald-500",
  yellow: "bg-amber-500",
  red: "bg-red-500",
  blue: "bg-blue-500",
  neutral: "bg-neutral-500",
};

interface ChartPoint {
  label: string;
  value: number;
}

function useLiveHistory(getter: () => number | null, maxPoints = 20) {
  const [history, setHistory] = useState<ChartPoint[]>([]);
  const getterRef = React.useRef(getter);

  useEffect(() => {
    getterRef.current = getter;
  }, [getter]);

  useEffect(() => {
    const tick = () => {
      const value = getterRef.current();
      if (value === null) return;
      setHistory((prev) =>
        [...prev, { label: new Date().toLocaleTimeString(), value }].slice(-maxPoints)
      );
    };
    tick();
    const id = setInterval(tick, 5000);
    return () => clearInterval(id);
  }, [maxPoints]);

  return history;
}

function AnimatedNumber({ value, suffix = "" }: { value: number | string; suffix?: string }) {
  return (
    <span className="text-2xl font-bold tracking-tight tabular-nums transition-all duration-300">
      {value}
      {suffix}
    </span>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const { user, token, loading, logout } = useAuth();
  const {
    metrics,
    queue,
    workers,
    testRuns,
    activities,
  } = useDashboard();
  const [ready, setReady] = useState(false);
  const [images, setImages] = useState<BrowserImage[]>([]);
  const [sessions, setSessions] = useState<BrowserSession[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedImageId, setSelectedImageId] = useState<number | null>(null);
  const [starting, setStarting] = useState(false);
  const [stoppingId, setStoppingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  const [avatarStyle, setAvatarStyle] = useState<string | null>(null);

  useEffect(() => {
    setAvatarStyle(readAvatarStyle());
  }, []);

  useEffect(() => {
    if (!loading) {
      if (!token) {
        router.replace("/login");
      } else {
        setReady(true);
      }
    }
  }, [loading, token, router]);

  useEffect(() => {
    if (!ready || !token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const [imgRes, sessRes, projRes] = await Promise.all([
          api.listBrowserImages(token),
          api.listSessions(token),
          api.listProjects(token),
        ]);
        if (cancelled) return;
        setImages(imgRes.browser_images);
        setSessions(sessRes.sessions);
        setProjects(projRes.projects);
        setSelectedImageId((prev) => prev ?? imgRes.browser_images[0]?.id ?? null);
      } catch {
        if (!cancelled) setError("Failed to load dashboard data.");
      }
    };
    load();

    return () => {
      cancelled = true;
    };
  }, [ready, token]);

  useEffect(() => {
    const timer = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(timer);
  }, []);

  const activeSessions = sessions.filter((s) => s.status === "running" || s.status === "pending");

  const runningTests = useMemo(() => {
    return Object.values(testRuns).filter(
      (r) => r.status === "running" || r.status === "scheduling"
    );
  }, [testRuns]);

  const recentRuns = useMemo(() => {
    return Object.values(testRuns)
      .sort((a, b) => b.id - a.id)
      .slice(0, 10);
  }, [testRuns]);

  const queueDepthHistory = useLiveHistory(() => queue?.queue_size ?? null);
  const utilizationHistory = useLiveHistory(() => metrics?.worker_utilization ?? null);
  const successRateHistory = useLiveHistory(() => metrics?.success_rate ?? null);
  const durationHistory = useLiveHistory(() => metrics?.average_execution_time ?? null);
  const runningJobsHistory = useLiveHistory(() => metrics?.running_jobs ?? null);

  const overviewCards = [
    { label: "Total Projects", value: metrics?.total_projects ?? 0, icon: FolderKanban, suffix: "" },
    { label: "Running Test Runs", value: metrics?.running_test_runs ?? 0, icon: Rocket, suffix: "" },
    { label: "Queued Jobs", value: metrics?.queued_jobs ?? 0, icon: Timer, suffix: "" },
    { label: "Running Workers", value: metrics?.active_workers ?? 0, icon: Wrench, suffix: "" },
    { label: "Success Rate", value: metrics?.success_rate ?? 0, icon: CheckCircle2, suffix: "%" },
    { label: "Release Readiness", value: 92, icon: Zap, suffix: "%" },
    { label: "Avg Execution Time", value: metrics?.average_execution_time ?? 0, icon: Clock, suffix: "s" },
  ];

  const handleStart = async (browserName: string) => {
    setError(null);
    setStarting(true);
    try {
      const res = await api.startSession(token!, browserName);
      setSessions((prev) => [res.session, ...prev]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start session.");
    } finally {
      setStarting(false);
    }
  };

  const handleStop = async (id: number) => {
    setStoppingId(id);
    setError(null);
    try {
      const res = await api.stopSession(token!, id);
      setSessions((prev) => prev.map((s) => (s.id === id ? res.session : s)));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to stop session.");
    } finally {
      setStoppingId(null);
    }
  };

  const handleLogout = () => {
    logout();
    router.replace("/");
  };

  if (loading || !ready) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const selectedImage = images.find((i) => i.id === selectedImageId) ?? images[0] ?? null;

  return (
    <DashboardShell active="dashboard">
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">Mission Control</h1>
        <p className="text-sm text-neutral-400 mt-1">
          Real-time overview of your entire distributed execution platform.
        </p>
      </div>

      {error && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      {/* Overview Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 xl:grid-cols-7 gap-4 mb-10">
        {overviewCards.map((stat) => {
          const Icon = stat.icon;
          return (
            <div key={stat.label} className="p-5 rounded-xl glass-panel">
              <div className="flex items-center gap-3 mb-3">
                <Icon className="w-4 h-4 text-neutral-500" />
                <span className="text-xs text-neutral-500 font-medium">{stat.label}</span>
              </div>
              <AnimatedNumber value={stat.value} suffix={stat.suffix} />
            </div>
          );
        })}
      </div>

      <div className="grid lg:grid-cols-3 gap-6 mb-10">
        {/* Live Test Runs */}
        <div className="lg:col-span-2 rounded-xl glass-panel overflow-hidden">
          <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Rocket className="w-4 h-4 text-neutral-500" />
              <h2 className="text-sm font-semibold">Live Test Runs</h2>
            </div>
            <span className="text-xs text-emerald-400 flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" /> Live
            </span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                  <th className="text-left px-5 py-3 font-medium">Run</th>
                  <th className="text-left px-5 py-3 font-medium">Project</th>
                  <th className="text-left px-5 py-3 font-medium">Status</th>
                  <th className="text-left px-5 py-3 font-medium">Progress</th>
                  <th className="text-left px-5 py-3 font-medium">Jobs</th>
                  <th className="text-left px-5 py-3 font-medium">Duration</th>
                </tr>
              </thead>
              <tbody>
                {recentRuns.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-5 py-8 text-center text-sm text-neutral-500">
                      No test runs yet. Start one from a project.
                    </td>
                  </tr>
                ) : (
                  recentRuns.map((run) => (
                    <tr
                      key={run.id}
                      className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors cursor-pointer"
                      onClick={() => router.push(`/test-runs/${run.id}`)}
                    >
                      <td className="px-5 py-3.5 text-white font-medium">#{run.id}</td>
                      <td className="px-5 py-3.5 text-neutral-400">{run.project_name}</td>
                      <td className="px-5 py-3.5">
                        <StatusBadge status={run.status} pulse={run.status === "running" || run.status === "scheduling"} />
                      </td>
                      <td className="px-5 py-3.5">
                        <ProgressBar value={run.progress_percentage} />
                      </td>
                      <td className="px-5 py-3.5 text-neutral-400 tabular-nums">
                        {run.completed_jobs}/{run.total_jobs}
                      </td>
                      <td className="px-5 py-3.5 text-neutral-400 tabular-nums">
                        {run.started_at ? formatElapsed(now - Math.floor(new Date(run.started_at).getTime() / 1000)) : "—"}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Quick Queue */}
        <div className="rounded-xl glass-panel p-5 flex flex-col">
          <div className="flex items-center gap-2.5 mb-4">
            <Timer className="w-4 h-4 text-neutral-500" />
            <h2 className="text-sm font-semibold">Queue Depth</h2>
          </div>
          <div className="flex-1 min-h-[160px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={queueDepthHistory}>
                <defs>
                  <linearGradient id="queueGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="label" hide />
                <YAxis hide />
                <Tooltip
                  contentStyle={{ background: "rgba(0,0,0,0.8)", border: "1px solid rgba(255,255,255,0.1)" }}
                  itemStyle={{ color: "#fff" }}
                />
                <Area type="monotone" dataKey="value" stroke="#3b82f6" fill="url(#queueGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
          <div className="grid grid-cols-3 gap-2 mt-4">
            <div className="p-3 rounded-lg border border-neutral-900 bg-black/10 text-center">
              <p className="text-xl font-bold text-blue-400 tabular-nums">{queue?.queue_size ?? 0}</p>
              <p className="text-[10px] text-neutral-500 uppercase tracking-wider">Queued</p>
            </div>
            <div className="p-3 rounded-lg border border-neutral-900 bg-black/10 text-center">
              <p className="text-xl font-bold text-amber-400 tabular-nums">{queue?.running_jobs ?? 0}</p>
              <p className="text-[10px] text-neutral-500 uppercase tracking-wider">Running</p>
            </div>
            <div className="p-3 rounded-lg border border-neutral-900 bg-black/10 text-center">
              <p className="text-xl font-bold text-emerald-400 tabular-nums">{queue?.completed_today ?? 0}</p>
              <p className="text-[10px] text-neutral-500 uppercase tracking-wider">Today</p>
            </div>
          </div>
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-6 mb-10">
        {/* Worker Pool */}
        <div className="lg:col-span-2 rounded-xl glass-panel overflow-hidden">
          <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Wrench className="w-4 h-4 text-neutral-500" />
              <h2 className="text-sm font-semibold">Worker Pool</h2>
            </div>
            <div className="flex items-center gap-3 text-xs">
              <span className="text-emerald-400">{metrics?.active_workers ?? 0} Active</span>
              <span className="text-neutral-500">{metrics?.idle_workers ?? 0} Idle</span>
              <span className="text-red-400">{metrics?.offline_workers ?? 0} Offline</span>
            </div>
          </div>
          <div className="p-5 grid sm:grid-cols-2 xl:grid-cols-3 gap-4">
            {workers.length === 0 ? (
              <p className="col-span-full text-sm text-neutral-500">No workers registered yet.</p>
            ) : (
              workers.map((worker) => {
                const tone = workerTone(worker.status);
                const job = worker.current_job;
                return (
                  <div
                    key={worker.id}
                    className={`rounded-xl border p-4 ${
                      worker.status === "offline"
                        ? "border-red-500/30 bg-red-500/5"
                        : worker.status === "busy"
                        ? "border-amber-500/30 bg-amber-500/5"
                        : "border-neutral-800 bg-neutral-900/20"
                    }`}
                  >
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <span className="w-8 h-8 rounded-lg bg-white/5 border border-neutral-800 flex items-center justify-center">
                          <Cpu className={`w-4 h-4 ${TONE_TEXT[tone]}`} />
                        </span>
                        <div>
                          <p className="font-semibold text-sm">{worker.worker_name}</p>
                          <p className="text-[10px] text-neutral-500">heartbeat {relativeTime(worker.heartbeat_at)}</p>
                        </div>
                      </div>
                      <span className={`w-2 h-2 rounded-full ${TONE_BG[tone]} ${worker.status === "busy" ? "animate-pulse" : ""}`} />
                    </div>
                    {job ? (
                      <div className="mb-3 text-xs">
                        <p className="text-neutral-400 mb-1">
                          <span className="text-white font-medium">Job #{job.id}</span> · Chunk {job.chunk_number}
                        </p>
                        <p className="text-neutral-500">
                          {worker.browser} · {worker.container_status} · {job.started_at ? formatElapsed(now - Math.floor(new Date(job.started_at).getTime() / 1000)) : "—"}
                        </p>
                      </div>
                    ) : (
                      <p className="mb-3 text-xs text-neutral-500">No job assigned</p>
                    )}
                    <div className="space-y-2">
                      <div className="flex items-center justify-between text-[10px]">
                        <span className="text-neutral-500">CPU</span>
                        <span className="text-neutral-300 tabular-nums">{worker.cpu_usage?.toFixed(1) ?? "—"}%</span>
                      </div>
                      <div className="h-1 rounded-full bg-neutral-900 overflow-hidden">
                        <div className={`h-full ${worker.cpu_usage && worker.cpu_usage > 75 ? "bg-red-500" : worker.cpu_usage && worker.cpu_usage > 50 ? "bg-amber-500" : "bg-emerald-500"}`} style={{ width: `${Math.min(100, worker.cpu_usage ?? 0)}%` }} />
                      </div>
                      <div className="flex items-center justify-between text-[10px]">
                        <span className="text-neutral-500">Memory</span>
                        <span className="text-neutral-300 tabular-nums">{worker.memory_usage?.toFixed(1) ?? "—"}%</span>
                      </div>
                      <div className="h-1 rounded-full bg-neutral-900 overflow-hidden">
                        <div className={`h-full ${worker.memory_usage && worker.memory_usage > 75 ? "bg-red-500" : worker.memory_usage && worker.memory_usage > 50 ? "bg-amber-500" : "bg-emerald-500"}`} style={{ width: `${Math.min(100, worker.memory_usage ?? 0)}%` }} />
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Infrastructure Health */}
        <div className="rounded-xl glass-panel p-5 flex flex-col">
          <div className="flex items-center gap-2.5 mb-4">
            <ShieldCheck className="w-4 h-4 text-neutral-500" />
            <h2 className="text-sm font-semibold">Infrastructure</h2>
          </div>
          <div className="flex-1 space-y-2.5">
            {[
              { name: "Rails API", status: "ok" },
              { name: "Redis", status: "ok" },
              { name: "PostgreSQL", status: "ok" },
              { name: "Action Cable", status: "ok" },
              { name: "Worker Pool", status: metrics?.active_workers ? "ok" : "degraded" },
            ].map((item) => (
              <div key={item.name} className="flex items-center justify-between px-4 py-3 rounded-lg border border-neutral-900 bg-black/10">
                <div className="flex items-center gap-3">
                  <Database className="w-3.5 h-3.5 text-neutral-500" />
                  <span className="text-sm text-neutral-300">{item.name}</span>
                </div>
                <span className={`inline-flex items-center gap-1.5 text-xs font-medium ${item.status === "ok" ? "text-emerald-400" : "text-amber-400"}`}>
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  {item.status === "ok" ? "OK" : "Degraded"}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid lg:grid-cols-2 xl:grid-cols-3 gap-6 mb-10">
        <div className="rounded-xl glass-panel p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <BarChart3 className="w-4 h-4 text-neutral-500" />
            <h2 className="text-sm font-semibold">Worker Utilization</h2>
          </div>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={utilizationHistory}>
                <XAxis dataKey="label" hide />
                <YAxis domain={[0, 100]} hide />
                <Tooltip contentStyle={{ background: "rgba(0,0,0,0.8)", border: "1px solid rgba(255,255,255,0.1)" }} itemStyle={{ color: "#fff" }} />
                <Line type="monotone" dataKey="value" stroke="#10b981" strokeWidth={2} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="rounded-xl glass-panel p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <TrendingUp className="w-4 h-4 text-neutral-500" />
            <h2 className="text-sm font-semibold">Execution Success Rate</h2>
          </div>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={successRateHistory}>
                <XAxis dataKey="label" hide />
                <YAxis domain={[0, 100]} hide />
                <Tooltip contentStyle={{ background: "rgba(0,0,0,0.8)", border: "1px solid rgba(255,255,255,0.1)" }} itemStyle={{ color: "#fff" }} />
                <Line type="monotone" dataKey="value" stroke="#3b82f6" strokeWidth={2} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="rounded-xl glass-panel p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <Clock className="w-4 h-4 text-neutral-500" />
            <h2 className="text-sm font-semibold">Avg Execution Duration</h2>
          </div>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={durationHistory}>
                <defs>
                  <linearGradient id="durationGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#f59e0b" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="label" hide />
                <YAxis hide />
                <Tooltip contentStyle={{ background: "rgba(0,0,0,0.8)", border: "1px solid rgba(255,255,255,0.1)" }} itemStyle={{ color: "#fff" }} />
                <Area type="monotone" dataKey="value" stroke="#f59e0b" fill="url(#durationGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="rounded-xl glass-panel p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <Activity className="w-4 h-4 text-neutral-500" />
            <h2 className="text-sm font-semibold">Running Jobs Timeline</h2>
          </div>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={runningJobsHistory}>
                <defs>
                  <linearGradient id="runningJobsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="label" hide />
                <YAxis hide />
                <Tooltip contentStyle={{ background: "rgba(0,0,0,0.8)", border: "1px solid rgba(255,255,255,0.1)" }} itemStyle={{ color: "#fff" }} />
                <Area type="monotone" dataKey="value" stroke="#10b981" fill="url(#runningJobsGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-6 mb-10">
        {/* Currently Running Tests */}
        <div className="rounded-xl glass-panel p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <Play className="w-4 h-4 text-neutral-500" />
            <h2 className="text-sm font-semibold">Currently Running Tests</h2>
          </div>
          <div className="space-y-3">
            {runningTests.length === 0 ? (
              <p className="text-sm text-neutral-500">No tests running right now.</p>
            ) : (
              runningTests.map((run) => (
                <Link
                  key={run.id}
                  href={`/test-runs/${run.id}`}
                  className="block p-3 rounded-lg border border-neutral-900 bg-black/10 hover:bg-neutral-900/20 transition-colors"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium">#{run.id} {run.project_name}</span>
                    <span className="text-xs text-amber-400 animate-pulse">Running</span>
                  </div>
                  <ProgressBar value={run.progress_percentage} />
                  <div className="flex items-center justify-between text-xs text-neutral-500 mt-2">
                    <span>{run.running_jobs} running · {run.completed_jobs} completed</span>
                    <span>{run.started_at ? formatElapsed(now - Math.floor(new Date(run.started_at).getTime() / 1000)) : "—"}</span>
                  </div>
                </Link>
              ))
            )}
          </div>
        </div>

        {/* Recent Activity */}
        <div className="lg:col-span-2 rounded-xl glass-panel overflow-hidden">
          <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Activity className="w-4 h-4 text-neutral-500" />
              <h2 className="text-sm font-semibold">Recent Activity</h2>
            </div>
          </div>
          <div className="divide-y divide-neutral-900/50 max-h-[320px] overflow-y-auto">
            {activities.length === 0 ? (
              <div className="px-5 py-8 text-center text-sm text-neutral-500">No activity yet.</div>
            ) : (
              activities.slice(0, 50).map((event) => (
                <div key={event.id} className="flex items-center gap-3 px-5 py-3">
                  <span
                    className={`w-2 h-2 rounded-full ${
                      event.type === "success"
                        ? "bg-emerald-400"
                        : event.type === "error"
                        ? "bg-red-400"
                        : event.type === "warning"
                        ? "bg-amber-400"
                        : "bg-blue-400"
                    }`}
                  />
                  <span className="text-sm text-neutral-300">{event.text}</span>
                  <span className="ml-auto text-xs text-neutral-600 tabular-nums">{relativeTime(event.timestamp)}</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Browser sessions (preserved from Week 1) */}
      <div className="mb-10">
        <div className="mb-4">
          <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-1">Active Session</p>
          <h2 className="text-xl font-semibold tracking-tight">Start a browser</h2>
        </div>

        {activeSessions.length > 0 ? (
          <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/5 p-6">
            {activeSessions.map((session) => (
              <div key={session.id} className="flex items-center justify-between gap-6">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center">
                    <Box className="w-6 h-6 text-emerald-400" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2.5">
                      <h3 className="font-semibold">{session.browser_name}</h3>
                      <span className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-400">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                        {session.status === "pending" ? "Provisioning..." : "Running"}
                      </span>
                    </div>
                    <p className="text-xs text-neutral-400 mt-0.5">Session #{session.id}</p>
                  </div>
                </div>
                <div className="flex items-center gap-6">
                  <div className="text-right">
                    <p className="text-2xl font-bold tabular-nums tracking-tight">
                      {formatElapsed(now - Math.floor(new Date(session.start_time!).getTime() / 1000))}
                    </p>
                    <p className="text-xs text-neutral-500">elapsed</p>
                  </div>
                  <button
                    onClick={() => handleStop(session.id)}
                    disabled={stoppingId === session.id}
                    className="px-4 py-2 rounded-md border border-neutral-700 text-sm font-medium text-neutral-300 hover:border-red-500/50 hover:text-red-400 transition-colors flex items-center gap-1.5 disabled:opacity-50"
                  >
                    {stoppingId === session.id ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <Square className="w-3.5 h-3.5" />
                    )}
                    Stop
                  </button>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="rounded-xl glass-panel p-6">
            <p className="text-xs text-neutral-500 mb-4">Choose a browser to launch</p>
            <div className="grid sm:grid-cols-3 gap-3 mb-6">
              {images.length === 0 && (
                <div className="sm:col-span-3 flex items-center gap-3">
                  <div className="w-12 h-12 rounded-lg bg-neutral-900 border border-neutral-800 flex items-center justify-center">
                    <Globe className="w-6 h-6 text-neutral-500" />
                  </div>
                  <div>
                    <h3 className="font-semibold">Chrome 128</h3>
                    <p className="text-xs text-neutral-500 mt-0.5">No active session — start one below</p>
                  </div>
                </div>
              )}
              {images.map((image) => {
                const selected = selectedImage?.id === image.id;
                return (
                  <button
                    key={image.id}
                    onClick={() => setSelectedImageId(image.id)}
                    className={`flex items-center gap-3 p-4 rounded-lg border text-left transition-colors ${
                      selected
                        ? "border-white/40 bg-neutral-900"
                        : "border-neutral-900 bg-neutral-950 hover:bg-neutral-900/40 hover:border-neutral-700"
                    }`}
                  >
                    <div
                      className={`w-10 h-10 rounded-lg flex items-center justify-center border ${
                        selected ? "bg-white/10 border-white/20" : "bg-neutral-900 border-neutral-800"
                      }`}
                    >
                      <Globe className={`w-5 h-5 ${selected ? "text-white" : "text-neutral-500"}`} />
                    </div>
                    <div>
                      <p className="text-sm font-semibold">{image.name}</p>
                      <p className="text-xs text-neutral-500">v{image.version}</p>
                    </div>
                    <div
                      className={`ml-auto w-4 h-4 rounded-full border flex items-center justify-center ${
                        selected ? "border-white bg-white" : "border-neutral-700"
                      }`}
                    >
                      {selected && <span className="w-1.5 h-1.5 rounded-full bg-black" />}
                    </div>
                  </button>
                );
              })}
            </div>
            <div className="flex items-center justify-between gap-6">
              <div className="flex items-center gap-4">
                <p className="text-sm text-neutral-400">
                  Ready to launch <span className="text-white font-medium">{selectedImage ? `${selectedImage.name} ${selectedImage.version}` : "Chrome 128"}</span>
                </p>
              </div>
              <button
                onClick={() => handleStart(selectedImage?.name ?? "Chrome")}
                disabled={starting}
                className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 shadow-lg shadow-white/10 disabled:opacity-60"
              >
                {starting ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" /> Starting...
                  </>
                ) : (
                  <>
                    <Play className="w-4 h-4" /> Start Browser
                  </>
                )}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Session history */}
      <div className="rounded-xl glass-panel overflow-hidden">
        <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
          <h2 className="text-sm font-semibold">Session History</h2>
          <span className="text-xs text-neutral-500">{sessions.length} total</span>
        </div>
        {sessions.length === 0 ? (
          <div className="px-5 py-12 text-center">
            <p className="text-sm text-neutral-500">No sessions yet. Start your first browser session above.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                  <th className="text-left px-5 py-3 font-medium">Session</th>
                  <th className="text-left px-5 py-3 font-medium">Browser</th>
                  <th className="text-left px-5 py-3 font-medium">Status</th>
                  <th className="text-left px-5 py-3 font-medium">Started</th>
                  <th className="text-left px-5 py-3 font-medium">Duration</th>
                  <th className="text-right px-5 py-3 font-medium">Action</th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((session) => (
                  <tr key={session.id} className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors">
                    <td className="px-5 py-3.5 text-white font-medium">#{session.id}</td>
                    <td className="px-5 py-3.5 text-neutral-400">{session.browser_name}</td>
                    <td className="px-5 py-3.5">
                      <span
                        className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium ${
                          session.status === "running"
                            ? "bg-emerald-500/10 text-emerald-400"
                            : session.status === "pending"
                            ? "bg-amber-500/10 text-amber-400"
                            : session.status === "terminated"
                            ? "bg-neutral-800 text-neutral-400"
                            : "bg-blue-500/10 text-blue-400"
                        }`}
                      >
                        {(session.status === "running" || session.status === "pending") && (
                          <span className="w-1.5 h-1.5 rounded-full bg-current animate-pulse" />
                        )}
                        {session.status.charAt(0).toUpperCase() + session.status.slice(1)}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400">{relativeTime(session.start_time)}</td>
                    <td className="px-5 py-3.5 text-neutral-400">
                      {session.status === "running"
                        ? formatElapsed(now - Math.floor(new Date(session.start_time!).getTime() / 1000))
                        : formatDuration(session.elapsed)}
                    </td>
                    <td className="px-5 py-3.5 text-right">
                      {session.status === "running" || session.status === "pending" ? (
                        <button
                          onClick={() => handleStop(session.id)}
                          disabled={stoppingId === session.id}
                          className="text-neutral-500 hover:text-red-400 transition-colors disabled:opacity-50"
                          aria-label="Stop session"
                        >
                          {stoppingId === session.id ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            <Trash2 className="w-4 h-4" />
                          )}
                        </button>
                      ) : (
                        <span className="text-neutral-700">—</span>
                      )}
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
