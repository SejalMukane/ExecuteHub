"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  Server,
  User,
  LifeBuoy,
  LogOut,
  Loader2,
  FolderKanban,
  GitBranch,
  ArrowLeft,
  Lock,
  Globe,
  ExternalLink,
  Plug,
  Unplug,
  CheckCircle2,
  XCircle,
  Search,
  Webhook,
  Activity,
  Play,
  Rocket,
  Timer,
} from "lucide-react";
import GithubIcon from "@/components/GithubIcon";
import {
  api,
  Project,
  GithubStatus,
  GithubRepositoryOption,
  GithubRepository,
  GithubDelivery,
  TestSuite,
} from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import ThemeToggle from "@/components/ThemeToggle";

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleString();
}

export default function ProjectDetailPage() {
  const params = useParams<{ id: string }>();
  const projectId = Number(params.id);
  const router = useRouter();
  const { user, token, loading, logout } = useAuth();
  const [ready, setReady] = useState(false);

  const [project, setProject] = useState<Project | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [repositoryUrl, setRepositoryUrl] = useState("");
  const [saving, setSaving] = useState(false);

  const [github, setGithub] = useState<GithubStatus | null>(null);
  const [repo, setRepo] = useState<GithubRepository | null>(null);
  const [deliveries, setDeliveries] = useState<GithubDelivery[]>([]);

  const [showRepoModal, setShowRepoModal] = useState(false);
  const [repoOptions, setRepoOptions] = useState<GithubRepositoryOption[]>([]);
  const [repoSearch, setRepoSearch] = useState("");
  const [repoLoading, setRepoLoading] = useState(false);
  const [connectingRepo, setConnectingRepo] = useState<string | null>(null);

  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const [showRunModal, setShowRunModal] = useState(false);
  const [runBranch, setRunBranch] = useState("");
  const [runCommitSha, setRunCommitSha] = useState("");
  const [testSuites, setTestSuites] = useState<TestSuite[]>([]);
  const [selectedSuiteId, setSelectedSuiteId] = useState<number | "">("");
  const [runTotalTests, setRunTotalTests] = useState("100");
  const [startingRun, setStartingRun] = useState(false);

  useEffect(() => {
    if (!loading) {
      if (!token) {
        router.replace("/login");
      } else {
        setReady(true);
      }
    }
  }, [loading, token, router]);

  const loadProject = async () => {
    if (!token) return;
    const res = await api.listProjects(token);
    const found = res.projects.find((p) => p.id === projectId);
    if (!found) {
      setError("Project not found.");
      return;
    }
    setProject(found);
    setName(found.name);
    setDescription(found.description ?? "");
    setRepositoryUrl(found.repository_url ?? "");
  };

  const loadGithub = async () => {
    if (!token) return;
    try {
      const status = await api.githubStatus(token);
      setGithub(status);
      const repoRes = await api.getGithubRepository(token, projectId);
      setRepo(repoRes.github_repository);
      setDeliveries(repoRes.deliveries);
    } catch {
      setGithub({ connected: false, login: null });
    }
  };

  useEffect(() => {
    if (!ready || !token) return;
    let cancelled = false;

    const load = async () => {
      try {
        await Promise.all([loadProject(), loadGithub()]);
      } catch {
        if (!cancelled) setError("Failed to load project.");
      }
    };
    load();

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, token, projectId]);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !project) return;
    setSaving(true);
    setError(null);
    try {
      const res = await api.updateProject(token, project.id, {
        name,
        description: description || undefined,
        repositoryUrl: repositoryUrl || undefined,
      });
      setProject(res.project);
      setName(res.project.name);
      setDescription(res.project.description ?? "");
      setRepositoryUrl(res.project.repository_url ?? "");
      setNotice("Project settings saved.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save project.");
    } finally {
      setSaving(false);
    }
  };

  const handleConnectGithub = async () => {
    setError(null);
    try {
      const res = await api.githubOAuthStart(token!);
      window.location.href = res.url;
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start GitHub connection.");
    }
  };

  const handleOpenRepoModal = async () => {
    setShowRepoModal(true);
    setError(null);
    setRepoLoading(true);
    setRepoOptions([]);
    try {
      const res = await api.listGithubRepositories(token!);
      setRepoOptions(res.repositories);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load repositories.");
      setShowRepoModal(false);
    } finally {
      setRepoLoading(false);
    }
  };

  const handleConnectRepo = async (fullName: string) => {
    setConnectingRepo(fullName);
    setError(null);
    try {
      const res = await api.connectGithubRepository(token!, projectId, fullName);
      setRepo(res.github_repository);
      setShowRepoModal(false);
      setNotice(`Repository ${res.github_repository.full_name} connected. Webhook registered.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to connect repository.");
    } finally {
      setConnectingRepo(null);
    }
  };

  const handleDisconnectRepo = async () => {
    setError(null);
    try {
      await api.disconnectGithubRepository(token!, projectId);
      setRepo(null);
      setDeliveries([]);
      setNotice("Repository disconnected.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to disconnect repository.");
    }
  };

  const handleDisconnectGithub = async () => {
    setError(null);
    try {
      await api.githubDisconnect(token!);
      setGithub({ connected: false, login: null });
      setRepo(null);
      setDeliveries([]);
      setNotice("GitHub account disconnected.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to disconnect GitHub.");
    }
  };

  const handleLogout = () => {
    logout();
    router.replace("/");
  };

  const openRunModal = async () => {
    setShowRunModal(true);
    if (testSuites.length > 0) return;
    try {
      const res = await api.listTestSuites(token!);
      setTestSuites(res.test_suites);
      const smoke = res.test_suites.find((s) => s.name.toLowerCase().includes("smoke"));
      setSelectedSuiteId(smoke ? smoke.id : res.test_suites[0]?.id ?? "");
    } catch {
      setError("Failed to load test suites.");
    }
  };

  const handleRunTest = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !project) return;
    setStartingRun(true);
    setError(null);
    const selectedSuite = testSuites.find((s) => s.id === selectedSuiteId);
    try {
      const res = await api.createTestRun(token, project.id, {
        branch: runBranch || "main",
        commit_sha: runCommitSha || undefined,
        ...(selectedSuite
          ? { test_suite_id: selectedSuite.id }
          : { total_tests: parseInt(runTotalTests, 10) }),
      });
      setShowRunModal(false);
      setNotice(`Test run #${res.test_run.id} scheduled — ${res.test_run.total_jobs} job(s) queued.`);
      router.push(`/test-runs/${res.test_run.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start test run.");
    } finally {
      setStartingRun(false);
    }
  };

  if (loading || !ready) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const canWrite = user?.role === "admin" || user?.role === "developer";

  const navItems = [
    { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard, active: false },
    { label: "Projects", href: "/projects", icon: FolderKanban, active: true },
    { label: "Test Runs", href: "/test-runs", icon: Rocket, active: false },
    { label: "Queue", href: "/queue", icon: Timer, active: false },
    { label: "Browser Sessions", href: "/dashboard#sessions", icon: Server, active: false },
    { label: "Profile", href: "/profile", icon: User, active: false },
  ];

  const filteredRepos = repoOptions.filter((r) =>
    r.full_name.toLowerCase().includes(repoSearch.toLowerCase())
  );

  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-white selection:text-black relative overflow-hidden">
      {/* Dot grid */}
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.02]"
        style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, var(--dot) 1px, transparent 0)`,
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
              <ThemeToggle />
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
              <Link href="/projects" className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-white transition-colors mb-3">
                <ArrowLeft className="w-4 h-4" />
                All projects
              </Link>
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <h1 className="text-2xl font-bold tracking-tight">{project?.name ?? "Project"}</h1>
                  <p className="text-sm text-neutral-400 mt-1">Settings and GitHub repository connection.</p>
                </div>
                <div className="flex items-center gap-3">
                  {canWrite && (
                    <button
                      onClick={openRunModal}
                      className="px-4 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 shadow-lg shadow-white/10"
                    >
                      <Play className="w-4 h-4" />
                      Run Test
                    </button>
                  )}
                  {github?.connected && (
                    <div className="flex items-center gap-2 px-3.5 py-2 rounded-md border border-emerald-500/30 bg-emerald-500/10 text-emerald-400 text-sm">
                      <GithubIcon className="w-4 h-4" />
                      <span className="font-medium">@{github.login}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {notice && (
              <div className="mb-6 px-4 py-3 rounded-md border border-emerald-500/30 bg-emerald-500/10 text-emerald-400 text-sm flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0" />
                {notice}
              </div>
            )}

            {error && (
              <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm flex items-center gap-2">
                <XCircle className="w-4 h-4 shrink-0" />
                {error}
              </div>
            )}

            <div className="grid lg:grid-cols-2 gap-6">
              {/* Project settings */}
              <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 p-6">
                <div className="mb-5">
                  <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-1">Project Settings</p>
                  <h2 className="text-xl font-semibold tracking-tight">General</h2>
                </div>

                <form onSubmit={handleSave} className="space-y-4">
                  <div>
                    <label htmlFor="detail-name" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      Name
                    </label>
                    <input
                      id="detail-name"
                      type="text"
                      required
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      disabled={!canWrite}
                      className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors disabled:opacity-50"
                    />
                  </div>
                  <div>
                    <label htmlFor="detail-repo-url" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      Repository URL
                    </label>
                    <input
                      id="detail-repo-url"
                      type="url"
                      value={repositoryUrl}
                      onChange={(e) => setRepositoryUrl(e.target.value)}
                      disabled={!canWrite}
                      placeholder="https://github.com/acme/app"
                      className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors disabled:opacity-50"
                    />
                  </div>
                  <div>
                    <label htmlFor="detail-desc" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      Description
                    </label>
                    <textarea
                      id="detail-desc"
                      value={description}
                      onChange={(e) => setDescription(e.target.value)}
                      disabled={!canWrite}
                      rows={3}
                      className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors resize-none disabled:opacity-50"
                    />
                  </div>
                  {canWrite && (
                    <div className="flex justify-end">
                      <button
                        type="submit"
                        disabled={saving}
                        className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 shadow-lg shadow-white/10 disabled:opacity-50"
                      >
                        {saving ? (
                          <>
                            <Loader2 className="w-4 h-4 animate-spin" /> Saving...
                          </>
                        ) : (
                          "Save Changes"
                        )}
                      </button>
                    </div>
                  )}
                </form>
              </div>

              {/* GitHub repository */}
              <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 p-6">
                <div className="mb-5 flex items-center justify-between">
                  <div>
                    <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-1">GitHub</p>
                    <h2 className="text-xl font-semibold tracking-tight">Repository</h2>
                  </div>
                  {github?.connected && (
                    <button
                      onClick={handleDisconnectGithub}
                      className="text-xs text-neutral-500 hover:text-red-400 transition-colors flex items-center gap-1.5"
                    >
                      <Unplug className="w-3.5 h-3.5" />
                      Disconnect GitHub
                    </button>
                  )}
                </div>

                {!github?.connected ? (
                  <div className="py-6 text-center">
                    <GithubIcon className="w-10 h-10 text-neutral-600 mx-auto mb-4" />
                    <p className="text-sm text-neutral-300 font-medium">Connect your GitHub account</p>
                    <p className="text-xs text-neutral-500 mt-1 mb-5">Authorize ExecuteHub to list repositories and register webhooks.</p>
                    <button
                      onClick={handleConnectGithub}
                      className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 mx-auto shadow-lg shadow-white/10"
                    >
                      <GithubIcon className="w-4 h-4" />
                      Connect GitHub
                    </button>
                  </div>
                ) : !repo ? (
                  <div className="py-6 text-center">
                    <Plug className="w-10 h-10 text-neutral-600 mx-auto mb-4" />
                    <p className="text-sm text-neutral-300 font-medium">No repository linked</p>
                    <p className="text-xs text-neutral-500 mt-1 mb-5">Link a GitHub repository to this project. A webhook will be registered automatically.</p>
                    {canWrite ? (
                      <button
                        onClick={handleOpenRepoModal}
                        className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 mx-auto shadow-lg shadow-white/10"
                      >
                        <GitBranch className="w-4 h-4" />
                        Connect a repository
                      </button>
                    ) : (
                      <p className="text-xs text-neutral-600">You need admin or developer access to link a repository.</p>
                    )}
                  </div>
                ) : (
                  <div className="space-y-4">
                    {/* Repository info */}
                    <div className="rounded-lg border border-neutral-800 bg-neutral-900/40 p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex items-center gap-3 min-w-0">
                          <div className="w-9 h-9 rounded-lg bg-neutral-900 border border-neutral-800 flex items-center justify-center shrink-0">
                            <GitBranch className="w-4 h-4 text-neutral-400" />
                          </div>
                          <div className="min-w-0">
                            <a
                              href={repo.html_url ?? "#"}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-white font-medium hover:text-neutral-300 transition-colors flex items-center gap-1.5"
                            >
                              {repo.full_name}
                              <ExternalLink className="w-3.5 h-3.5 text-neutral-500" />
                            </a>
                            <p className="text-xs text-neutral-500 mt-0.5 flex items-center gap-1.5">
                              {repo.private ? (
                                <span className="inline-flex items-center gap-1"><Lock className="w-3 h-3" /> private</span>
                              ) : (
                                <span className="inline-flex items-center gap-1"><Globe className="w-3 h-3" /> public</span>
                              )}
                              <span>·</span>
                              <span>default branch: {repo.default_branch ?? "—"}</span>
                            </p>
                          </div>
                        </div>
                        {canWrite && (
                          <button
                            onClick={handleDisconnectRepo}
                            className="text-xs text-neutral-500 hover:text-red-400 transition-colors flex items-center gap-1.5 shrink-0"
                          >
                            <Unplug className="w-3.5 h-3.5" />
                            Disconnect
                          </button>
                        )}
                      </div>
                      {repo.description && <p className="text-xs text-neutral-400 mt-2">{repo.description}</p>}
                      <div className="mt-3 pt-3 border-t border-neutral-800 grid grid-cols-2 gap-3 text-xs">
                        <div>
                          <p className="text-neutral-500">HTTPS clone</p>
                          <p className="text-neutral-300 font-mono truncate">{repo.clone_url ?? "—"}</p>
                        </div>
                        <div>
                          <p className="text-neutral-500">SSH clone</p>
                          <p className="text-neutral-300 font-mono truncate">{repo.ssh_url ?? "—"}</p>
                        </div>
                      </div>
                    </div>

                    {/* Webhook status */}
                    <div className="rounded-lg border border-neutral-800 bg-neutral-900/40 p-4">
                      <div className="flex items-center justify-between">
                        <h3 className="text-sm font-semibold flex items-center gap-2">
                          <Webhook className="w-4 h-4 text-neutral-400" />
                          Webhook
                        </h3>
                        <span
                          className={`inline-flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-full ${
                            repo.webhook?.active
                              ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/30"
                              : "bg-red-500/10 text-red-400 border border-red-500/30"
                          }`}
                        >
                          <span className={`w-1.5 h-1.5 rounded-full ${repo.webhook?.active ? "bg-emerald-400" : "bg-red-400"}`} />
                          {repo.webhook?.active ? "Active" : "Inactive"}
                        </span>
                      </div>
                      {repo.webhook ? (
                        <div className="mt-3 space-y-2 text-xs">
                          <div>
                            <p className="text-neutral-500">Events</p>
                            <div className="flex flex-wrap gap-1.5 mt-1">
                              {repo.webhook.events.map((ev) => (
                                <span key={ev} className="px-2 py-0.5 rounded bg-neutral-800 border border-neutral-700 text-neutral-300 font-mono">
                                  {ev}
                                </span>
                              ))}
                            </div>
                          </div>
                          <div>
                            <p className="text-neutral-500">Payload URL</p>
                            <p className="text-neutral-300 font-mono break-all mt-1">{repo.webhook.url}</p>
                          </div>
                          <div className="flex items-center justify-between pt-2">
                            <p className="text-neutral-500">Last delivery</p>
                            <p className="text-neutral-300">{relativeTime(repo.webhook.last_delivery_at)}</p>
                          </div>
                        </div>
                      ) : (
                        <p className="text-xs text-neutral-500 mt-3">No webhook registered.</p>
                      )}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Deliveries */}
            {repo && (
              <div className="mt-8 rounded-xl border border-neutral-900 bg-neutral-950/50 overflow-hidden">
                <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
                  <h2 className="text-sm font-semibold flex items-center gap-2">
                    <Activity className="w-4 h-4 text-neutral-400" />
                    Recent Webhook Deliveries
                  </h2>
                  <span className="text-xs text-neutral-500">{deliveries.length} recent</span>
                </div>
                {deliveries.length === 0 ? (
                  <div className="px-5 py-12 text-center">
                    <p className="text-sm text-neutral-500">No deliveries yet. Webhook events will appear here.</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                          <th className="text-left px-5 py-3 font-medium">Event</th>
                          <th className="text-left px-5 py-3 font-medium">Delivery</th>
                          <th className="text-left px-5 py-3 font-medium">Signature</th>
                          <th className="text-left px-5 py-3 font-medium">Branch</th>
                          <th className="text-right px-5 py-3 font-medium">Received</th>
                        </tr>
                      </thead>
                      <tbody>
                        {deliveries.map((d) => {
                          const ref = d.payload?.ref;
                          const branch = typeof ref === "string" ? ref.replace("refs/heads/", "") : "—";
                          return (
                            <tr key={d.id} className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors">
                              <td className="px-5 py-3.5">
                                <span className="px-2 py-0.5 rounded bg-neutral-800 border border-neutral-700 text-neutral-300 font-mono text-xs">
                                  {d.event ?? "—"}
                                </span>
                              </td>
                              <td className="px-5 py-3.5 text-neutral-400 font-mono text-xs">{d.delivery_id ?? "—"}</td>
                              <td className="px-5 py-3.5">
                                {d.signature_valid ? (
                                  <span className="inline-flex items-center gap-1.5 text-emerald-400 text-xs">
                                    <CheckCircle2 className="w-3.5 h-3.5" /> Verified
                                  </span>
                                ) : (
                                  <span className="inline-flex items-center gap-1.5 text-red-400 text-xs">
                                    <XCircle className="w-3.5 h-3.5" /> Failed
                                  </span>
                                )}
                              </td>
                              <td className="px-5 py-3.5 text-neutral-400 font-mono text-xs">{branch}</td>
                              <td className="px-5 py-3.5 text-neutral-400 text-xs text-right">{relativeTime(d.received_at)}</td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}
          </main>
        </div>
      </div>

      {/* Repository selection modal */}
      {showRepoModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/80 backdrop-blur-sm" onClick={() => setShowRepoModal(false)} />
          <div className="relative w-full max-w-lg rounded-xl border border-neutral-800 bg-neutral-950 p-6 shadow-2xl">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">Select a repository</h3>
              <button onClick={() => setShowRepoModal(false)} className="text-neutral-500 hover:text-white transition-colors" aria-label="Close">
                <XCircle className="w-5 h-5" />
              </button>
            </div>

            <div className="relative mb-4">
              <Search className="w-4 h-4 text-neutral-500 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={repoSearch}
                onChange={(e) => setRepoSearch(e.target.value)}
                placeholder="Search repositories..."
                className="w-full pl-9 pr-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-900 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
              />
            </div>

            <div className="max-h-80 overflow-y-auto space-y-2">
              {repoLoading ? (
                <div className="py-10 text-center">
                  <Loader2 className="w-6 h-6 animate-spin text-neutral-500 mx-auto" />
                </div>
              ) : filteredRepos.length === 0 ? (
                <div className="py-10 text-center">
                  <p className="text-sm text-neutral-500">No repositories found.</p>
                </div>
              ) : (
                filteredRepos.map((r) => (
                  <button
                    key={r.id}
                    onClick={() => handleConnectRepo(r.full_name)}
                    disabled={connectingRepo !== null}
                    className="w-full flex items-center justify-between gap-3 px-4 py-3 rounded-lg border border-neutral-800 bg-neutral-900/40 hover:bg-neutral-900 transition-colors text-left disabled:opacity-50"
                  >
                    <div className="min-w-0">
                      <p className="text-sm font-medium text-white flex items-center gap-2">
                        {r.full_name}
                        {r.private && <Lock className="w-3 h-3 text-neutral-500" />}
                      </p>
                      {r.description && <p className="text-xs text-neutral-500 truncate mt-0.5">{r.description}</p>}
                    </div>
                    {connectingRepo === r.full_name ? (
                      <Loader2 className="w-4 h-4 animate-spin text-neutral-400 shrink-0" />
                    ) : (
                      <GitBranch className="w-4 h-4 text-neutral-500 shrink-0" />
                    )}
                  </button>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      {/* Run Test modal */}
      {showRunModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/80 backdrop-blur-sm" onClick={() => setShowRunModal(false)} />
          <div className="relative w-full max-w-md rounded-xl border border-neutral-800 bg-neutral-950 p-6 shadow-2xl">
            <div className="flex items-center justify-between mb-5">
              <h3 className="text-lg font-semibold flex items-center gap-2">
                <Play className="w-4 h-4 text-neutral-400" />
                Run Test
              </h3>
              <button onClick={() => setShowRunModal(false)} className="text-neutral-500 hover:text-white transition-colors" aria-label="Close">
                <XCircle className="w-5 h-5" />
              </button>
            </div>

            <p className="text-xs text-neutral-500 mb-4">
              This schedules a new test run for <span className="text-neutral-300 font-medium">{project?.name}</span>. Tests
              are split into chunks and queued for background execution.
            </p>

            <form onSubmit={handleRunTest} className="space-y-4">
              <div>
                <label htmlFor="run-suite" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                  Test Suite
                </label>
                <select
                  id="run-suite"
                  value={selectedSuiteId}
                  onChange={(e) => setSelectedSuiteId(e.target.value === "" ? "" : Number(e.target.value))}
                  className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-900 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                >
                  <option value="" disabled>
                    Select a suite...
                  </option>
                  {testSuites.map((suite) => (
                    <option key={suite.id} value={suite.id}>
                      {suite.name} — {suite.total_tests} tests
                    </option>
                  ))}
                  <option value="">Custom (manual count)</option>
                </select>
                {selectedSuiteId !== "" && (
                  <p className="text-xs text-neutral-500 mt-1.5">
                    {testSuites.find((s) => s.id === selectedSuiteId)?.description} Split into chunks
                    of 20 per job.
                  </p>
                )}
              </div>

              {selectedSuiteId === "" && (
                <div>
                  <label htmlFor="run-tests" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                    Total Tests
                  </label>
                  <input
                    id="run-tests"
                    type="number"
                    required
                    min={1}
                    value={runTotalTests}
                    onChange={(e) => setRunTotalTests(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-900 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                  />
                  <p className="text-xs text-neutral-500 mt-1.5">
                    Tests are split into chunks of 20 per job.
                  </p>
                </div>
              )}

              <div>
                <label htmlFor="run-branch" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                  Branch
                </label>
                <input
                  id="run-branch"
                  type="text"
                  value={runBranch}
                  onChange={(e) => setRunBranch(e.target.value)}
                  placeholder="main"
                  className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-900 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                />
              </div>

              <div>
                <label htmlFor="run-commit" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                  Commit SHA <span className="text-neutral-600">(optional)</span>
                </label>
                <input
                  id="run-commit"
                  type="text"
                  value={runCommitSha}
                  onChange={(e) => setRunCommitSha(e.target.value)}
                  placeholder="e.g. a1b2c3d4e5f6..."
                  className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-900 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors font-mono"
                />
              </div>

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowRunModal(false)}
                  className="px-4 py-2.5 text-sm text-neutral-400 hover:text-white transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={startingRun}
                  className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 shadow-lg shadow-white/10 disabled:opacity-50"
                >
                  {startingRun ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" /> Scheduling...
                    </>
                  ) : (
                    <>
                      <Play className="w-4 h-4" /> Start Run
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
