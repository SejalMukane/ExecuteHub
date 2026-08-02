"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowRight, Loader2, User } from "lucide-react";
import { api, User as UserType } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import ThemeToggle from "@/components/ThemeToggle";
import BackgroundBlobs from "@/components/BackgroundBlobs";
import { avatarUrl, getInitials, readAvatarStyle } from "@/lib/avatar";

export default function LoginPage() {
  const router = useRouter();
  const { setAuth } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [phase, setPhase] = useState<"form" | "found">("form");
  const [foundUser, setFoundUser] = useState<UserType | null>(null);
  const [avatarStyle, setAvatarStyle] = useState<string | null>(null);

  useEffect(() => {
    setAvatarStyle(readAvatarStyle());
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api.login(email, password);
      setAuth(res.user, res.token);
      setFoundUser(res.user);
      setAvatarStyle(readAvatarStyle());
      setPhase("found");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-white selection:text-black relative overflow-hidden flex flex-col">
      {/* Dot grid */}
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.03]"
        style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, var(--dot) 1px, transparent 0)`,
          backgroundSize: "40px 40px",
        }}
      />

      {/* Ambient glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[400px] bg-neutral-800/20 rounded-full blur-3xl pointer-events-none" />

      {/* Ambient color blobs for the glassmorphism */}
      <BackgroundBlobs />

      <div className="relative z-10 flex-1 flex flex-col">
        {/* Header */}
        <header className="h-16 max-w-7xl mx-auto w-full px-6 flex items-center justify-between glass-header">
          <Link href="/" className="font-bold tracking-tight text-base hover:text-neutral-300 transition-colors">
            ExecuteHub
          </Link>
          <ThemeToggle />
        </header>

        {/* Login form / found your account */}
        <main className="flex-1 flex items-center justify-center px-6">
          <div key={phase} className="w-full max-w-sm animate-fade-up">
            {phase === "form" ? (
              <>
                <div className="mb-8">
                  <h1 className="text-2xl font-bold tracking-tight mb-2">Welcome back</h1>
                  <p className="text-sm text-neutral-400">Sign in to your account to continue.</p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-5">
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
                      placeholder="you@example.com"
                      className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                    />
                  </div>

                  <div>
                    <label htmlFor="password" className="text-sm font-medium text-neutral-300 mb-1.5 block">
                      Password
                    </label>
                    <input
                      id="password"
                      type="password"
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Enter your password"
                      className="w-full px-3.5 py-2.5 text-sm rounded-md glass-input text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
                    />
                  </div>

                  {error && (
                    <div className="px-3.5 py-2.5 text-sm rounded-md border border-red-500/30 bg-red-500/10 text-red-400">
                      {error}
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-white/10 disabled:opacity-60 disabled:hover:bg-white disabled:hover:scale-100 flex items-center justify-center gap-2"
                  >
                    {loading ? (
                      <>
                        <Loader2 className="w-4 h-4 animate-spin" /> Signing in...
                      </>
                    ) : (
                      <>
                        Sign In <ArrowRight className="w-4 h-4" />
                      </>
                    )}
                  </button>
                </form>

                <p className="mt-6 text-sm text-neutral-500 text-center">
                  Don&apos;t have an account?{" "}
                  <Link href="/register" className="text-white hover:text-neutral-300 transition-colors font-medium">
                    Sign up
                  </Link>
                </p>
              </>
            ) : (
              <div className="rounded-xl glass-panel p-8 text-center">
                <div className="relative mx-auto w-24 h-24 mb-5">
                  <div className="w-24 h-24 rounded-full overflow-hidden border border-neutral-800 animate-pop-in">
                    {avatarStyle ? (
                      <img
                        src={avatarUrl(avatarStyle, foundUser?.email ?? foundUser?.name ?? "user")}
                        alt="Your avatar"
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full bg-neutral-900 flex items-center justify-center">
                        {getInitials(foundUser?.name ?? "") ? (
                          <span className="text-xl font-semibold text-neutral-300">{getInitials(foundUser?.name ?? "")}</span>
                        ) : (
                          <User className="w-9 h-9 text-neutral-400" />
                        )}
                      </div>
                    )}
                  </div>
                  <div className="absolute -bottom-1 -right-1 w-8 h-8 rounded-full bg-emerald-500 flex items-center justify-center border-2 border-black">
                    <svg className="w-4 h-4 text-black" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M20 6 9 17l-5-5" />
                    </svg>
                  </div>
                </div>

                <h2 className="text-2xl font-bold tracking-tight mb-2">Found your account</h2>
                <p className="text-sm text-neutral-400 mb-1">{foundUser?.email}</p>
                <p className="text-xs text-neutral-500 mb-6">Welcome back, {foundUser?.name}!</p>

                <button
                  type="button"
                  onClick={() => router.push("/dashboard")}
                  className="w-full px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-white/10 flex items-center justify-center gap-2"
                >
                  Continue to Dashboard <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            )}
          </div>
        </main>

        {/* Footer */}
        <footer className="h-16 max-w-7xl mx-auto w-full px-6 flex items-center border-t border-neutral-900">
          <p className="text-xs text-neutral-500">&copy; ExecuteHub</p>
        </footer>
      </div>
    </div>
  );
}
