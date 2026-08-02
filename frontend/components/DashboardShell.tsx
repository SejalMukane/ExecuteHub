"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  LayoutDashboard,
  FolderKanban,
  Server,
  User,
  LifeBuoy,
  LogOut,
  Rocket,
  Timer,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import ThemeToggle from "@/components/ThemeToggle";
import BackgroundBlobs from "@/components/BackgroundBlobs";
import { avatarUrl, getInitials, readAvatarStyle } from "@/lib/avatar";

export type NavKey =
  | "dashboard"
  | "projects"
  | "test-runs"
  | "queue"
  | "sessions"
  | "profile";

const NAV_ITEMS: { label: string; href: string; key: NavKey; icon: typeof LayoutDashboard }[] = [
  { label: "Dashboard", href: "/dashboard", key: "dashboard", icon: LayoutDashboard },
  { label: "Projects", href: "/projects", key: "projects", icon: FolderKanban },
  { label: "Test Runs", href: "/test-runs", key: "test-runs", icon: Rocket },
  { label: "Queue", href: "/queue", key: "queue", icon: Timer },
  { label: "Browser Sessions", href: "/dashboard#sessions", key: "sessions", icon: Server },
  { label: "Profile", href: "/profile", key: "profile", icon: User },
];

export default function DashboardShell({
  active,
  children,
}: {
  active: NavKey;
  children: React.ReactNode;
}) {
  const router = useRouter();
  const { user, logout } = useAuth();
  const [avatarStyle, setAvatarStyle] = useState<string | null>(null);

  useEffect(() => {
    setAvatarStyle(readAvatarStyle());
  }, []);

  const handleLogout = () => {
    logout();
    router.replace("/");
  };

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
              <ThemeToggle />
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
              {NAV_ITEMS.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.key}
                    href={item.href}
                    className={`flex items-center gap-3 px-3.5 py-2.5 rounded-lg text-sm transition-colors ${
                      active === item.key
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
          <main className="flex-1 min-w-0 py-8">{children}</main>
        </div>
      </div>
    </div>
  );
}
