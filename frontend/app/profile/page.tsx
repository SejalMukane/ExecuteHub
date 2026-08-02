"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { User, Mail, Calendar, Save, ArrowLeft, Loader2, CheckCircle2, AlertCircle, KeyRound, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import ThemeToggle from "@/components/ThemeToggle";
import BackgroundBlobs from "@/components/BackgroundBlobs";
import { AVATAR_STYLES, avatarUrl, getInitials, readAvatarStyle, saveAvatarStyle } from "@/lib/avatar";

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
  const [avatarStyle, setAvatarStyle] = useState<string | null>(null);

  useEffect(() => {
    if (!loading) {
      if (!token) {
        router.replace("/login");
      } else {
        setName(user?.name ?? "");
        setEmail(user?.email ?? "");
        setAvatarStyle(readAvatarStyle());
        setReady(true);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, token, router]);

  const selectAvatar = (style: string) => {
    setAvatarStyle(style);
    saveAvatarStyle(style);
  };

  const removeAvatar = () => {
    setAvatarStyle(null);
    saveAvatarStyle(null);
  };

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
          backgroundImage: `radial-gradient(circle at 1px 1px, var(--dot) 1px, transparent 0)`,
          backgroundSize: "40px 40px",
        }}
      />

      {/* Ambient color blobs for the glassmorphism */}
      <BackgroundBlobs />

      <div className="relative z-10">
        {/* Top nav */}
        <header className="h-16 glass-header sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-6 h-full flex items-center justify-between">
            <div className="flex items-center gap-8">
              <Link href="/" className="font-bold tracking-tight text-base">ExecuteHub</Link>
              <nav className="hidden sm:flex items-center gap-6 text-sm">
                <Link href="/dashboard" className="text-neutral-400 hover:text-white transition-colors">Dashboard</Link>
                <Link href="/projects" className="text-neutral-400 hover:text-white transition-colors">Projects</Link>
                <span className="text-white font-medium">Profile</span>
              </nav>
            </div>
            <ThemeToggle />
          </div>
        </header>

        <main className="max-w-2xl mx-auto px-6 py-8">
          {/* Back link */}
          <Link href="/dashboard" className="inline-flex items-center gap-1.5 text-xs text-neutral-400 hover:text-white transition-colors mb-6">
            <ArrowLeft className="w-3.5 h-3.5" /> Back to Dashboard
          </Link>

          {/* Profile header */}
          <div className="flex items-center gap-5 mb-10">
            {avatarStyle ? (
              <img
                src={avatarUrl(avatarStyle, user?.email ?? user?.name ?? "user")}
                alt="Profile avatar"
                className="w-14 h-14 rounded-full border border-neutral-800 object-cover"
              />
            ) : (
              <div className="w-14 h-14 rounded-full bg-neutral-900 flex items-center justify-center border border-neutral-800">
                {getInitials(user?.name ?? "") ? (
                  <span className="text-sm font-semibold text-neutral-300">{getInitials(user?.name ?? "")}</span>
                ) : (
                  <User className="w-6 h-6 text-neutral-400" />
                )}
              </div>
            )}
            <div>
              <h1 className="text-xl font-bold tracking-tight">{user?.name}</h1>
              <p className="text-sm text-neutral-400">{user?.email}</p>
            </div>
          </div>

          {/* Profile photo */}
          <div className="rounded-xl glass-panel p-6 mb-6">
            <h2 className="text-sm font-semibold mb-1">Profile Photo</h2>
            <p className="text-xs text-neutral-500 mb-5">Pick an avatar style — it will be shown across your workspace.</p>

            <div className="flex items-center gap-5">
              <div className="w-20 h-20 rounded-full bg-neutral-900 flex items-center justify-center border border-neutral-800 shrink-0 overflow-hidden">
                {avatarStyle ? (
                  <img
                    src={avatarUrl(avatarStyle, user?.email ?? user?.name ?? "user")}
                    alt="Profile avatar"
                    className="w-full h-full object-cover"
                  />
                ) : getInitials(user?.name ?? "") ? (
                  <span className="text-xl font-semibold text-neutral-300">{getInitials(user?.name ?? "")}</span>
                ) : (
                  <User className="w-8 h-8 text-neutral-400" />
                )}
              </div>
              <div className="text-xs text-neutral-400">
                {avatarStyle ? (
                  <span>
                    Using <span className="text-white font-medium">{AVATAR_STYLES.find((s) => s.id === avatarStyle)?.label}</span>
                  </span>
                ) : (
                  <span>No custom avatar yet</span>
                )}
              </div>
            </div>

            <div className="mt-5 grid grid-cols-5 gap-3">
              {AVATAR_STYLES.map((style) => {
                const selected = avatarStyle === style.id;
                return (
                  <button
                    key={style.id}
                    type="button"
                    onClick={() => selectAvatar(style.id)}
                    className={`flex flex-col items-center gap-1.5 rounded-lg p-2 transition-colors ${
                      selected ? "bg-white/10 ring-1 ring-white/40" : "hover:bg-white/5"
                    }`}
                  >
                    <img
                      src={avatarUrl(style.id, user?.email ?? user?.name ?? "user")}
                      alt={style.label}
                      className="w-12 h-12 rounded-full object-cover"
                      onError={(e) => { e.currentTarget.style.display = "none"; }}
                    />
                    <span className={`text-[10px] leading-none ${selected ? "text-white" : "text-neutral-400"}`}>
                      {style.label}
                    </span>
                  </button>
                );
              })}
            </div>

            {avatarStyle && (
              <button
                type="button"
                onClick={removeAvatar}
                className="mt-4 inline-flex items-center gap-1.5 text-xs text-neutral-400 hover:text-red-400 transition-colors"
              >
                <Trash2 className="w-3.5 h-3.5" /> Remove photo
              </button>
            )}
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
          <div className="rounded-xl glass-panel p-6">
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
                  className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
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
                  className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
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
                      className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
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
                      className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
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
          <div className="mt-6 rounded-xl glass-panel p-6">
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
