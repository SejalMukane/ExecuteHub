"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Activity,
  Globe,
  Clock,
  Box,
  LogOut,
  Play,
  Square,
  Loader2,
  Trash2,
  LayoutDashboard,
  User,
  Server,
  LifeBuoy,
  FolderKanban,
  Rocket,
  Timer,
  Wrench,
  CheckCircle2,
  GitBranch,
  Package,
  Bell,
  Database,
  ShieldCheck,
} from "lucide-react";
import { api, BrowserImage, BrowserSession, Project } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

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

const liveTestRuns = [
  { id: 102, project: "E-Commerce", progress: 65, status: "running" },
  { id: 101, project: "Inventory", progress: 100, status: "passed" },
  { id: 100, project: "Payment", progress: 42, status: "running" },
];

const workerPool = [
  { worker: "Worker-1", browser: "Chrome", status: "running" },
  { worker: "Worker-2", browser: "Firefox", status: "idle" },
  { worker: "Worker-3", browser: "Chromium", status: "running" },
  { worker: "Worker-4", browser: "WebKit", status: "offline" },
];

const infraHealth = [
  { name: "Rails API", status: "ok" },
  { name: "Redis", status: "ok" },
  { name: "PostgreSQL", status: "ok" },
  { name: "Kubernetes Cluster", status: "ok" },
  { name: "Worker Pool", status: "ok" },
];

const recentActivity = [
  { text: "Test Run #105 Completed", type: "done" },
  { text: "GitHub Webhook Received", type: "done" },
  { text: "Worker Spawned", type: "done" },
  { text: "Artifact Uploaded", type: "done" },
  { text: "Slack Notification Sent", type: "done" },
];

export default function DashboardPage() {
  const router = useRouter();
  const { user, token, loading, logout } = useAuth();
  const [ready, setReady] = useState(false);

  const [images, setImages] = useState<BrowserImage[]>([]);
  const [sessions, setSessions] = useState<BrowserSession[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedImageId, setSelectedImageId] = useState<number | null>(null);
  const [starting, setStarting] = useState(false);
  const [stoppingId, setStoppingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));

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
  const activeWorkers = workerPool.filter((w) => w.status === "running").length;
  const idleWorkers = workerPool.filter((w) => w.status === "idle").length;
  const failedWorkers = workerPool.filter((w) => w.status === "offline").length;
  const pendingJobs = 12;
  const avgWaitTime = 18;

  const summaryCards = [
    { label: "Total Projects", value: String(projects.length), icon: FolderKanban },
    { label: "Active Test Runs", value: String(liveTestRuns.filter((r) => r.status === "running").length), icon: Rocket },
    { label: "Pending Queue", value: `${pendingJobs}`, icon: Timer },
    { label: "Active Workers", value: String(activeWorkers), icon: Wrench },
    { label: "Success Rate (24h)", value: "96.4%", icon: CheckCircle2 },
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

  const navItems = [
    { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard, active: true },
    { label: "Projects", href: "/projects", icon: FolderKanban, active: false },
    { label: "Test Runs", href: "/test-runs", icon: Rocket, active: false },
    { label: "Queue", href: "/queue", icon: Timer, active: false },
    { label: "Browser Sessions", href: "/dashboard#sessions", icon: Server, active: false },
    { label: "Profile", href: "/profile", icon: User, active: false },
  ];

  const statusBadge = (status: string) => {
    if (status === "running") return "bg-emerald-500/10 text-emerald-400";
    if (status === "passed") return "bg-blue-500/10 text-blue-400";
    if (status === "idle") return "bg-neutral-800 text-neutral-400";
    if (status === "offline") return "bg-red-500/10 text-red-400";
    return "bg-neutral-800 text-neutral-400";
  };

  const statusDot = (status: string) => {
    if (status === "running") return "bg-emerald-500";
    if (status === "passed") return "bg-blue-500";
    if (status === "idle") return "bg-neutral-500";
    if (status === "offline") return "bg-red-500";
    return "bg-neutral-500";
  };

  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-white selection:text-black relative overflow-hidden">
      {/* Dot grid */}
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.02]"
        style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, white 1px, transparent 0)`,
          backgroundSize: "40px 40px",
        }}
      />

      <div className="relative z-10 min-h-screen">
        {/* Top bar */}
        <header className="h-16 border-b border-neutral-900 bg-black/80 backdrop-blur-md sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-6 h-full flex items-center justify-between">
            <div className="flex items-center gap-8">
              <Link href="/" className="font-bold tracking-tight text-base">ExecuteHub</Link>
            </div>
            <div className="flex items-center gap-4">
              <Bell className="w-4 h-4 text-neutral-500" />
              <span className="text-xs text-neutral-500 hidden sm:block">{user?.email}</span>
              <button onClick={handleLogout} className="text-neutral-400 hover:text-white transition-colors" aria-label="Log out">
                <LogOut className="w-4 h-4" />
              </button>
            </div>
          </div>
        </header>

        <div className="max-w-7xl mx-auto px-6 flex gap-10">
          {/* Sidebar navigation */}
          <aside className="hidden md:block w-56 shrink-0 py-8">
            <nav className="flex flex-col gap-1">
              {navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.label}
                    href={item.href}
                    className={`flex items-center gap-3 px-3.5 py-2.5 rounded-lg text-sm transition-colors ${
                      item.active
                        ? "bg-white/10 text-white font-medium"
                        : "text-neutral-400 hover:text-white hover:bg-white/5"
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    {item.label}
                  </Link>
                );
              })}
            </nav>

            <div className="mt-8 pt-6 border-t border-neutral-900">
              <div className="flex items-center gap-3 px-3.5 py-2.5 text-xs text-neutral-500">
                <LifeBuoy className="w-4 h-4" />
                Help & Support
              </div>
            </div>
          </aside>

          {/* Main content */}
          <main className="flex-1 min-w-0 py-8">
            {/* Page header */}
            <div className="mb-8">
              <h1 className="text-2xl font-bold tracking-tight">
                Welcome back, {user?.name.split(" ")[0]}
              </h1>
              <p className="text-sm text-neutral-400 mt-1">Overview of your browser infrastructure and test executions.</p>
            </div>

            {error && (
              <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
                {error}
              </div>
            )}

            {/* Top Summary Cards */}
            <div className="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-10">
              {summaryCards.map((stat) => {
                const Icon = stat.icon;
                return (
                  <div key={stat.label} className="p-5 rounded-xl border border-neutral-900 bg-neutral-950/50">
                    <div className="flex items-center gap-3 mb-3">
                      <Icon className="w-4 h-4 text-neutral-500" />
                      <span className="text-xs text-neutral-500 font-medium">{stat.label}</span>
                    </div>
                    <span className="text-2xl font-bold tracking-tight">{stat.value}</span>
                  </div>
                );
              })}
            </div>

            <div className="grid lg:grid-cols-3 gap-6 mb-10">
              {/* Live Test Runs */}
              <div className="lg:col-span-2 rounded-xl border border-neutral-900 bg-neutral-950/50 overflow-hidden">
                <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
                  <div className="flex items-center gap-2.5">
                    <Rocket className="w-4 h-4 text-neutral-500" />
                    <h2 className="text-sm font-semibold">Live Test Runs</h2>
                  </div>
                  <span className="text-xs text-neutral-500">Real-time</span>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                        <th className="text-left px-5 py-3 font-medium">Test Run</th>
                        <th className="text-left px-5 py-3 font-medium">Project</th>
                        <th className="text-left px-5 py-3 font-medium">Progress</th>
                        <th className="text-left px-5 py-3 font-medium">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {liveTestRuns.map((run) => (
                        <tr key={run.id} className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors">
                          <td className="px-5 py-3.5 text-white font-medium">#{run.id}</td>
                          <td className="px-5 py-3.5 text-neutral-400">{run.project}</td>
                          <td className="px-5 py-3.5">
                            <div className="flex items-center gap-3">
                              <div className="w-32 h-1.5 rounded-full bg-neutral-900 overflow-hidden">
                                <div
                                  className={`h-full rounded-full ${run.status === "passed" ? "bg-blue-500" : "bg-emerald-500"}`}
                                  style={{ width: `${run.progress}%` }}
                                />
                              </div>
                              <span className="text-xs text-neutral-400 tabular-nums">{run.progress}%</span>
                            </div>
                          </td>
                          <td className="px-5 py-3.5">
                            <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium ${statusBadge(run.status)}`}>
                              <span className={`w-1.5 h-1.5 rounded-full ${statusDot(run.status)} ${run.status === "running" ? "animate-pulse" : ""}`} />
                              {run.status.charAt(0).toUpperCase() + run.status.slice(1)}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Queue Status */}
              <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 p-5 flex flex-col">
                <div className="flex items-center gap-2.5 mb-4">
                  <Timer className="w-4 h-4 text-neutral-500" />
                  <h2 className="text-sm font-semibold">Queue Status</h2>
                </div>
                <div className="flex-1 space-y-4">
                  <div className="p-4 rounded-lg border border-neutral-900 bg-black/40">
                    <p className="text-2xl font-bold tracking-tight">{pendingJobs}</p>
                    <p className="text-xs text-neutral-500 mt-1">Jobs Waiting</p>
                  </div>
                  <div className="p-4 rounded-lg border border-neutral-900 bg-black/40">
                    <p className="text-2xl font-bold tracking-tight">{avgWaitTime}s</p>
                    <p className="text-xs text-neutral-500 mt-1">Average Wait Time</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="grid lg:grid-cols-3 gap-6 mb-10">
              {/* Worker Pool */}
              <div className="lg:col-span-2 rounded-xl border border-neutral-900 bg-neutral-950/50 overflow-hidden">
                <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
                  <div className="flex items-center gap-2.5">
                    <Wrench className="w-4 h-4 text-neutral-500" />
                    <h2 className="text-sm font-semibold">Worker Pool</h2>
                  </div>
                  <div className="flex items-center gap-3 text-xs">
                    <span className="text-emerald-400">{activeWorkers} Active</span>
                    <span className="text-neutral-500">{idleWorkers} Idle</span>
                    <span className="text-red-400">{failedWorkers} Failed</span>
                  </div>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                        <th className="text-left px-5 py-3 font-medium">Worker</th>
                        <th className="text-left px-5 py-3 font-medium">Browser</th>
                        <th className="text-left px-5 py-3 font-medium">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {workerPool.map((w) => (
                        <tr key={w.worker} className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors">
                          <td className="px-5 py-3.5 text-white font-medium">{w.worker}</td>
                          <td className="px-5 py-3.5 text-neutral-400">{w.browser}</td>
                          <td className="px-5 py-3.5">
                            <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium ${statusBadge(w.status)}`}>
                              <span className={`w-1.5 h-1.5 rounded-full ${statusDot(w.status)} ${w.status === "running" ? "animate-pulse" : ""}`} />
                              {w.status.charAt(0).toUpperCase() + w.status.slice(1)}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Infrastructure Health */}
              <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 p-5 flex flex-col">
                <div className="flex items-center gap-2.5 mb-4">
                  <ShieldCheck className="w-4 h-4 text-neutral-500" />
                  <h2 className="text-sm font-semibold">Infrastructure Health</h2>
                </div>
                <div className="flex-1 space-y-2.5">
                  {infraHealth.map((item) => (
                    <div key={item.name} className="flex items-center justify-between px-4 py-3 rounded-lg border border-neutral-900 bg-black/40">
                      <div className="flex items-center gap-3">
                        <Database className="w-3.5 h-3.5 text-neutral-500" />
                        <span className="text-sm text-neutral-300">{item.name}</span>
                      </div>
                      <span className="inline-flex items-center gap-1.5 text-xs font-medium text-emerald-400">
                        <CheckCircle2 className="w-3.5 h-3.5" />
                        {item.status === "ok" ? "OK" : item.status}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Recent Activity */}
            <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 overflow-hidden mb-10">
              <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <Activity className="w-4 h-4 text-neutral-500" />
                  <h2 className="text-sm font-semibold">Recent Activity</h2>
                </div>
              </div>
              <div className="divide-y divide-neutral-900/50">
                {recentActivity.map((event, idx) => (
                  <div key={idx} className="flex items-center gap-3 px-5 py-3.5">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
                    <span className="text-sm text-neutral-300">{event.text}</span>
                    <span className="ml-auto text-xs text-neutral-600">now</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Browser sessions */}
            <div id="sessions" className="mb-10">
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
                <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 p-6">
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
            <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 overflow-hidden">
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
          </main>
        </div>
      </div>
    </div>
  );
}
