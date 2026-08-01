"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { User, Mail, Calendar, Save, ArrowLeft, Loader2, CheckCircle2, AlertCircle, KeyRound } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

export default function ProfilePage() {
  const router = useRouter();
  const { user, token, loading, updateUser } = useAuth();
  const [ready, setReady] = useState(false);

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState<{ type: "success" | "error"; message: string } | null>(null);

  useEffect(() => {
    if (!loading) {
      if (!token) {
        router.replace("/login");
      } else {
        setName(user?.name ?? "");
        setEmail(user?.email ?? "");
        setReady(true);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, token, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFeedback(null);

    if (password !== passwordConfirmation) {
      setFeedback({ type: "error", message: "Passwords do not match." });
      return;
    }

    setSaving(true);
    try {
      const res = await api.updateProfile(token!, {
        name,
        email,
        ...(password ? { password, passwordConfirmation } : {}),
      });
      updateUser(res.user);
      setName(res.user.name);
      setEmail(res.user.email);
      setPassword("");
      setPasswordConfirmation("");
      setFeedback({ type: "success", message: "Profile updated successfully." });
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Failed to update profile.";
      setFeedback({ type: "error", message: msg });
    } finally {
      setSaving(false);
    }
  };

  if (loading || !ready) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  const memberSince = user?.created_at
    ? new Date(user.created_at).toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
      })
    : "—";

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

      <div className="relative z-10">
        {/* Top nav */}
        <header className="h-16 border-b border-neutral-900 bg-black/80 backdrop-blur-md sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-6 h-full flex items-center justify-between">
            <div className="flex items-center gap-8">
              <Link href="/" className="font-bold tracking-tight text-base">BrowserCloud</Link>
              <nav className="hidden sm:flex items-center gap-6 text-sm">
                <Link href="/dashboard" className="text-neutral-400 hover:text-white transition-colors">Dashboard</Link>
                <span className="text-white font-medium">Profile</span>
              </nav>
            </div>
          </div>
        </header>

        <main className="max-w-2xl mx-auto px-6 py-8">
          {/* Back link */}
          <Link href="/dashboard" className="inline-flex items-center gap-1.5 text-xs text-neutral-400 hover:text-white transition-colors mb-6">
            <ArrowLeft className="w-3.5 h-3.5" /> Back to Dashboard
          </Link>

          {/* Profile header */}
          <div className="flex items-center gap-5 mb-10">
            <div className="w-14 h-14 rounded-full bg-neutral-900 flex items-center justify-center border border-neutral-800">
              <User className="w-6 h-6 text-neutral-400" />
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight">{user?.name}</h1>
              <p className="text-sm text-neutral-400">{user?.email}</p>
            </div>
          </div>

          {/* Feedback */}
          {feedback && (
            <div
              className={`mb-6 px-4 py-3 rounded-md border text-sm flex items-center gap-2.5 ${
                feedback.type === "success"
                  ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-400"
                  : "border-red-500/30 bg-red-500/10 text-red-400"
              }`}
            >
              {feedback.type === "success" ? (
                <CheckCircle2 className="w-4 h-4 shrink-0" />
              ) : (
                <AlertCircle className="w-4 h-4 shrink-0" />
              )}
              {feedback.message}
            </div>
          )}

          {/* Profile form */}
          <div className="rounded-xl border border-neutral-900 bg-neutral-950/50 p-6">
            <h2 className="text-sm font-semibold mb-6">Account Information</h2>

            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label htmlFor="name" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                  Name
                </label>
                <input
                  id="name"
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                />
              </div>

              <div>
                <label htmlFor="email" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                  Email
                </label>
                <input
                  id="email"
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                />
              </div>

              <div className="border-t border-neutral-900 pt-5">
                <div className="flex items-center gap-2 mb-4">
                  <KeyRound className="w-4 h-4 text-neutral-500" />
                  <h3 className="text-sm font-semibold">Change Password</h3>
                </div>
                <div className="space-y-5">
                  <div>
                    <label htmlFor="new-password" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      New Password
                    </label>
                    <input
                      id="new-password"
                      type="password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Leave blank to keep current"
                      className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                    />
                  </div>
                  <div>
                    <label htmlFor="confirm-password" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      Confirm New Password
                    </label>
                    <input
                      id="confirm-password"
                      type="password"
                      value={passwordConfirmation}
                      onChange={(e) => setPasswordConfirmation(e.target.value)}
                      placeholder="Re-enter new password"
                      className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                    />
                  </div>
                </div>
              </div>

              <div className="pt-2 flex items-center gap-4">
                <button
                  type="submit"
                  disabled={saving}
                  className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-white/10 disabled:opacity-60 disabled:hover:bg-white disabled:hover:scale-100 flex items-center gap-2"
                >
                  {saving ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" /> Saving...
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4" /> Save Changes
                    </>
                  )}
                </button>
                {feedback?.type === "success" && !saving && (
                  <span className="text-xs text-emerald-400">All changes saved</span>
                )}
              </div>
            </form>
          </div>

          {/* Account info */}
          <div className="mt-6 rounded-xl border border-neutral-900 bg-neutral-950/50 p-6">
            <h2 className="text-sm font-semibold mb-4">Account Details</h2>
            <div className="space-y-3">
              <div className="flex items-center gap-3 text-sm">
                <Calendar className="w-4 h-4 text-neutral-500" />
                <span className="text-neutral-400">Member since:</span>
                <span className="text-white">{memberSince}</span>
              </div>
              <div className="flex items-center gap-3 text-sm">
                <Mail className="w-4 h-4 text-neutral-500" />
                <span className="text-neutral-400">Email verified:</span>
                <span className="text-emerald-400">Yes</span>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}
