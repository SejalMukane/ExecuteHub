"use client";

import React, { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import {
  LayoutDashboard,
  Server,
  User,
  LifeBuoy,
  LogOut,
  Loader2,
  FolderKanban,
  Plus,
  Trash2,
  GitBranch,
  CheckCircle2,
  AlertTriangle,
  Rocket,
  Timer,
} from "lucide-react";
import GithubIcon from "@/components/GithubIcon";
import { api, Project, GithubStatus } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import ThemeToggle from "@/components/ThemeToggle";
import BackgroundBlobs from "@/components/BackgroundBlobs";
import { avatarUrl, getInitials, readAvatarStyle } from "@/lib/avatar";

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

function ProjectsPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { user, token, loading, logout } = useAuth();
  const [ready, setReady] = useState(false);
  const [avatarStyle, setAvatarStyle] = useState<string | null>(null);

  useEffect(() => {
    setAvatarStyle(readAvatarStyle());
  }, []);

  const [projects, setProjects] = useState<Project[]>([]);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [repositoryUrl, setRepositoryUrl] = useState("");
  const [creating, setCreating] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [github, setGithub] = useState<GithubStatus | null>(null);
  const [githubConnecting, setGithubConnecting] = useState(false);

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

    api
      .listProjects(token)
      .then((res) => {
        if (!cancelled) setProjects(res.projects);
      })
      .catch(() => {
        if (!cancelled) setError("Failed to load projects.");
      });

    api
      .githubStatus(token)
      .then((res) => {
        if (!cancelled) setGithub(res);
      })
      .catch(() => {
        if (!cancelled) setGithub({ connected: false, login: null });
      });

    return () => {
      cancelled = true;
    };
  }, [ready, token]);

  useEffect(() => {
    const status = searchParams.get("github");
    if (status === "connected" || status === "error") {
      router.replace("/projects");
    }
  }, [searchParams, router]);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setCreating(true);
    try {
      const res = await api.createProject(token!, {
        name,
        description: description || undefined,
        repositoryUrl: repositoryUrl || undefined,
      });
      setProjects((prev) => [res.project, ...prev]);
      setName("");
      setDescription("");
      setRepositoryUrl("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create project.");
    } finally {
      setCreating(false);
    }
  };

  const handleDelete = async (id: number) => {
    setDeletingId(id);
    setError(null);
    try {
      await api.deleteProject(token!, id);
      setProjects((prev) => prev.filter((p) => p.id !== id));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete project.");
    } finally {
      setDeletingId(null);
    }
  };

  const handleLogout = () => {
    logout();
    router.replace("/");
  };

  const handleConnectGithub = async () => {
    setGithubConnecting(true);
    setError(null);
    try {
      const res = await api.githubOAuthStart(token!);
      window.location.href = res.url;
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start GitHub connection.");
      setGithubConnecting(false);
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

  const oauthNotice = searchParams.get("github");

  const navItems = [
    { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard, active: false },
    { label: "Projects", href: "/projects", icon: FolderKanban, active: true },
    { label: "Test Runs", href: "/test-runs", icon: Rocket, active: false },
    { label: "Queue", href: "/queue", icon: Timer, active: false },
    { label: "Browser Sessions", href: "/dashboard#sessions", icon: Server, active: false },
    { label: "Profile", href: "/profile", icon: User, active: false },
  ];

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

      {/* Ambient color blobs for the glassmorphism */}
      <BackgroundBlobs />

      <div className="relative z-10 min-h-screen">
        {/* Top bar */}
        <header className="h-16 glass-header sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-6 h-full flex items-center justify-between">
            <div className="flex items-center gap-8">
              <Link href="/" className="font-bold tracking-tight text-base">ExecuteHub</Link>
            </div>
            <div className="flex items-center gap-4">
              <ThemeToggle />
              <span className="hidden sm:flex items-center gap-2.5 text-xs text-neutral-500">
                {avatarStyle ? (
                  <img
                    src={avatarUrl(avatarStyle, user?.email ?? user?.name ?? "user")}
                    alt=""
                    className="w-7 h-7 rounded-full object-cover border border-neutral-800"
                  />
                ) : (
                  <span className="w-7 h-7 rounded-full bg-neutral-900 border border-neutral-800 flex items-center justify-center">
                    {getInitials(user?.name ?? "") && (
                      <span className="text-[10px] font-semibold text-neutral-300">{getInitials(user?.name ?? "")}</span>
                    )}
                  </span>
                )}
                {user?.email}
              </span>
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
            <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold tracking-tight">Projects</h1>
                <p className="text-sm text-neutral-400 mt-1">Create and manage the applications your team tests.</p>
              </div>
              <div className="flex items-center gap-3">
                {github?.connected ? (
                  <div className="flex items-center gap-2 px-3.5 py-2 rounded-md border border-emerald-500/30 bg-emerald-500/10 text-emerald-400 text-sm">
                    <GithubIcon className="w-4 h-4" />
                    <span className="hidden sm:inline">GitHub</span>
                    <span className="font-medium">@{github.login}</span>
                  </div>
                ) : (
                  <button
                    onClick={handleConnectGithub}
                    disabled={githubConnecting || !canWrite}
                    className="px-4 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 shadow-lg shadow-white/10 disabled:opacity-50"
                  >
                    {githubConnecting ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <GithubIcon className="w-4 h-4" />
                    )}
                    Connect GitHub
                  </button>
                )}
              </div>
            </div>

            {oauthNotice === "connected" && (
              <div className="mb-6 px-4 py-3 rounded-md border border-emerald-500/30 bg-emerald-500/10 text-emerald-400 text-sm flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0" />
                GitHub connected successfully. You can now link repositories to projects.
              </div>
            )}

            {oauthNotice === "error" && (
              <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 shrink-0" />
                GitHub connection failed. Please try again.
              </div>
            )}

            {error && (
              <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 shrink-0" />
                {error}
              </div>
            )}

            {/* Create project */}
            <div className="mb-10 rounded-xl glass-panel p-6">
              <div className="mb-5">
                <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-1">New Project</p>
                <h2 className="text-xl font-semibold tracking-tight">Create a project</h2>
              </div>

              <form onSubmit={handleCreate} className="space-y-4">
                <div className="grid md:grid-cols-2 gap-4">
                  <div>
                    <label htmlFor="project-name" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      Name
                    </label>
                    <input
                      id="project-name"
                      type="text"
                      required
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      placeholder="E-Commerce App"
                      className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                    />
                  </div>
                  <div>
                    <label htmlFor="project-repo" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      Repository URL
                    </label>
                    <input
                      id="project-repo"
                      type="url"
                      value={repositoryUrl}
                      onChange={(e) => setRepositoryUrl(e.target.value)}
                      placeholder="https://github.com/acme/app"
                      className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                    />
                  </div>
                </div>

                <div>
                  <label htmlFor="project-desc" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                    Description
                  </label>
                  <textarea
                    id="project-desc"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="What does this project cover?"
                    rows={2}
                    className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors resize-none"
                  />
                </div>

                <div className="flex items-center justify-between gap-4">
                  <p className="text-xs text-neutral-500">
                    Signed in as <span className="text-neutral-300 font-medium">{user?.role}</span>
                  </p>
                  <button
                    type="submit"
                    disabled={creating || !canWrite}
                    className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 transition-colors flex items-center gap-2 shadow-lg shadow-white/10 disabled:opacity-50 disabled:hover:bg-white"
                  >
                    {creating ? (
                      <>
                        <Loader2 className="w-4 h-4 animate-spin" /> Creating...
                      </>
                    ) : (
                      <>
                        <Plus className="w-4 h-4" /> Create Project
                      </>
                    )}
                  </button>
                </div>
              </form>
            </div>

            {/* Project listing */}
            <div className="rounded-xl glass-panel overflow-hidden">
              <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
                <h2 className="text-sm font-semibold">All Projects</h2>
                <span className="text-xs text-neutral-500">{projects.length} total</span>
              </div>
              {projects.length === 0 ? (
                <div className="px-5 py-12 text-center">
                  <p className="text-sm text-neutral-500">No projects yet. Create your first project above.</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-neutral-900 text-xs text-neutral-500 uppercase tracking-wider">
                        <th className="text-left px-5 py-3 font-medium">Project</th>
                        <th className="text-left px-5 py-3 font-medium">Repository</th>
                        <th className="text-left px-5 py-3 font-medium">Created</th>
                        <th className="text-right px-5 py-3 font-medium">Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {projects.map((project) => (
                        <tr key={project.id} className="border-b border-neutral-900/50 hover:bg-neutral-900/20 transition-colors">
                          <td className="px-5 py-3.5">
                            <div className="flex items-center gap-3">
                              <div className="w-9 h-9 rounded-lg bg-neutral-900 border border-neutral-800 flex items-center justify-center">
                                <FolderKanban className="w-4 h-4 text-neutral-400" />
                              </div>
                              <div>
                                <Link
                                  href={`/projects/${project.id}`}
                                  className="text-white font-medium hover:text-neutral-300 transition-colors"
                                >
                                  {project.name}
                                </Link>
                                {project.description && (
                                  <p className="text-xs text-neutral-500 mt-0.5">{project.description}</p>
                                )}
                              </div>
                            </div>
                          </td>
                          <td className="px-5 py-3.5">
                            {project.repository_url ? (
                              <span className="inline-flex items-center gap-1.5 text-neutral-400">
                                <GitBranch className="w-3.5 h-3.5" />
                                {project.repository_url.replace(/^https?:\/\//, "").replace(/\/+$/, "")}
                              </span>
                            ) : (
                              <span className="text-neutral-700">—</span>
                            )}
                          </td>
                          <td className="px-5 py-3.5 text-neutral-400">{relativeTime(project.created_at)}</td>
                          <td className="px-5 py-3.5 text-right">
                            <div className="flex items-center justify-end gap-3">
                              <Link
                                href={`/projects/${project.id}`}
                                className="text-neutral-500 hover:text-white transition-colors text-xs font-medium uppercase tracking-wider"
                              >
                                Settings
                              </Link>
                              {canWrite ? (
                                <button
                                  onClick={() => handleDelete(project.id)}
                                  disabled={deletingId === project.id}
                                  className="text-neutral-500 hover:text-red-400 transition-colors disabled:opacity-50"
                                  aria-label="Delete project"
                                >
                                  {deletingId === project.id ? (
                                    <Loader2 className="w-4 h-4 animate-spin" />
                                  ) : (
                                    <Trash2 className="w-4 h-4" />
                                  )}
                                </button>
                              ) : (
                                <span className="text-neutral-700">—</span>
                              )}
                            </div>
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

export default function ProjectsPage() {
  return (
    <Suspense fallback={null}>
      <ProjectsPageContent />
    </Suspense>
  );
}
