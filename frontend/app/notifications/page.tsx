"use client";

import React, { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Bell, CheckCheck } from "lucide-react";
import { toast } from "sonner";
import DashboardShell from "@/components/DashboardShell";
import { api, Notification } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return new Date(iso).toLocaleDateString();
}

export default function NotificationsPage() {
  const router = useRouter();
  const { token, loading } = useAuth();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<boolean>(false);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const res = await api.listNotifications(token);
        if (cancelled) return;
        setNotifications(res.notifications);
      } catch (err) {
        if (!cancelled)
          setError(err instanceof Error ? err.message : "Failed to load notifications.");
      }
    };

    load();

    return () => {
      cancelled = true;
    };
  }, [token]);

  const markRead = async (notification: Notification) => {
    if (!token || notification.read) return;
    try {
      await api.markNotificationRead(token, notification.id);
      setNotifications((prev) =>
        prev.map((n) => (n.id === notification.id ? { ...n, read: true } : n))
      );
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to mark as read");
    }
  };

  const markAllRead = async () => {
    if (!token) return;
    setBusy(true);
    try {
      await api.markAllNotificationsRead(token);
      setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
      toast.success("All notifications marked as read");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to mark all as read");
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

  const unreadCount = notifications.filter((n) => !n.read).length;

  return (
    <DashboardShell active="notifications">
      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Notifications</h1>
          <p className="text-sm text-neutral-400 mt-1">
            Test run outcomes, pipeline results, and release gate actions.
          </p>
        </div>
        {unreadCount > 0 && (
          <button
            onClick={markAllRead}
            disabled={busy}
            className="inline-flex items-center gap-2 rounded-md bg-white/10 text-white text-sm font-medium px-3.5 py-2 hover:bg-white/20 disabled:opacity-50 transition-colors"
          >
            <CheckCheck className="w-4 h-4" />
            Mark all read
          </button>
        )}
      </div>

      {error && (
        <div className="mb-6 px-4 py-3 rounded-md border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
          {error}
        </div>
      )}

      <div className="rounded-xl glass-panel overflow-hidden">
        <div className="px-5 py-4 border-b border-neutral-900 flex items-center justify-between">
          <h2 className="text-sm font-semibold">All Notifications</h2>
          <span className="text-xs text-neutral-500">
            {unreadCount > 0 ? `${unreadCount} unread` : "all caught up"}
          </span>
        </div>

        {notifications.length === 0 ? (
          <div className="px-5 py-12 text-center">
            <Bell className="w-8 h-8 text-neutral-600 mx-auto mb-3" />
            <p className="text-sm text-neutral-500">
              No notifications yet. You will see pipeline and gate activity here.
            </p>
          </div>
        ) : (
          <ul className="divide-y divide-neutral-900/50">
            {notifications.map((notification) => (
              <li key={notification.id}>
                <button
                  onClick={() => markRead(notification)}
                  className={`w-full text-left px-5 py-4 transition-colors hover:bg-neutral-900/20 ${
                    notification.read ? "" : "bg-white/[0.02]"
                  }`}
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0">
                      <p
                        className={`text-sm ${
                          notification.read ? "text-neutral-400" : "text-white font-medium"
                        }`}
                      >
                        {notification.title}
                      </p>
                      {notification.description && (
                        <p className="text-xs text-neutral-500 mt-1">{notification.description}</p>
                      )}
                      <p className="text-xs text-neutral-600 mt-2">{relativeTime(notification.created_at)}</p>
                    </div>
                    <span
                      className={`inline-flex items-center gap-1.5 shrink-0 text-[10px] font-medium uppercase tracking-wider px-2 py-1 rounded-full border ${
                        notification.category === "deployment_gate"
                          ? "border-amber-500/30 text-amber-400 bg-amber-500/10"
                          : notification.category === "pipeline"
                          ? "border-blue-500/30 text-blue-400 bg-blue-500/10"
                          : "border-neutral-700/50 text-neutral-400 bg-neutral-800"
                      }`}
                    >
                      {notification.category.replace("_", " ")}
                    </span>
                  </div>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </DashboardShell>
  );
}