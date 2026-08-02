"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowRight, Loader2, Check, User, CheckCircle2 } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import ThemeToggle from "@/components/ThemeToggle";
import BackgroundBlobs from "@/components/BackgroundBlobs";
import { AVATAR_STYLES, avatarUrl, getInitials, saveAvatarStyle } from "@/lib/avatar";

type Phase = "form" | "avatar" | "welcome";

export default function RegisterPage() {
  const router = useRouter();
  const { setAuth } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [phase, setPhase] = useState<Phase>("form");
  const [avatarStyle, setAvatarStyle] = useState<string | null>(null);

  const avatarSeed = email.trim() || name.trim() || "user";

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api.register(name, email, password, password);
      setAuth(res.user, res.token);
      setPhase("avatar");
    } catch (err) {
      if (err instanceof Error && "errors" in err && Array.isArray((err as { errors?: string[] }).errors)) {
        setError((err as { errors?: string[] }).errors!.join(", "));
      } else {
        setError(err instanceof Error ? err.message : "Registration failed");
      }
    } finally {
      setLoading(false);
    }
  };

  const selectAvatar = (style: string) => {
    setAvatarStyle(style);
    saveAvatarStyle(style);
    setTimeout(() => setPhase("welcome"), 450);
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

        {/* Step content */}
        <main className="flex-1 flex items-center justify-center px-6">
          <div key={phase} className="w-full max-w-sm animate-fade-up">
            {phase === "form" ? (
              <>
                <div className="mb-8">
                  <h1 className="text-2xl font-bold tracking-tight mb-2">Create an account</h1>
                  <p className="text-sm text-neutral-400">Get started with ExecuteHub in seconds.</p>
                </div>

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
                      placeholder="John Doe"
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
                      minLength={8}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Create a password"
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
                        <Loader2 className="w-4 h-4 animate-spin" /> Creating account...
                      </>
                    ) : (
                      <>
                        Create Account <ArrowRight className="w-4 h-4" />
                      </>
                    )}
                  </button>
                </form>

                <p className="mt-6 text-sm text-neutral-500 text-center">
                  Already have an account?{" "}
                  <Link href="/login" className="text-white hover:text-neutral-300 transition-colors font-medium">
                    Sign in
                  </Link>
                </p>
              </>
            ) : phase === "avatar" ? (
              <div className="rounded-xl glass-panel p-6">
                <div className="text-center mb-6">
                  <h2 className="text-lg font-bold tracking-tight mb-1">Choose your avatar</h2>
                  <p className="text-xs text-neutral-400">Pick a style that represents you.</p>
                </div>

                <div className="w-24 h-24 mx-auto mb-6 rounded-full bg-neutral-900 border border-neutral-800 flex items-center justify-center overflow-hidden animate-scale-in">
                  {avatarStyle ? (
                    <img
                      src={avatarUrl(avatarStyle, avatarSeed)}
                      alt="Avatar preview"
                      className="w-full h-full object-cover"
                    />
                  ) : getInitials(name) ? (
                    <span className="text-xl font-semibold text-neutral-300">{getInitials(name)}</span>
                  ) : (
                    <User className="w-9 h-9 text-neutral-400" />
                  )}
                </div>

                <div className="flex gap-2 overflow-x-auto pb-2 -mb-2">
                  {AVATAR_STYLES.map((style) => {
                    const selected = avatarStyle === style.id;
                    return (
                      <button
                        key={style.id}
                        type="button"
                        onClick={() => selectAvatar(style.id)}
                        title={style.label}
                        className={`relative w-12 h-12 shrink-0 rounded-full overflow-hidden border transition-colors ${
                          selected ? "border-white ring-2 ring-white/30" : "border-neutral-800 hover:border-neutral-600"
                        }`}
                      >
                        <img
                          src={avatarUrl(style.id, avatarSeed)}
                          alt={style.label}
                          className="w-full h-full object-cover"
                          onError={(e) => { e.currentTarget.style.display = "none"; }}
                        />
                        {selected && (
                          <span className="absolute inset-0 bg-black/30 flex items-center justify-center">
                            <Check className="w-4 h-4 text-white" />
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            ) : (
              <div className="rounded-xl glass-panel p-8 text-center">
                <div className="relative mx-auto w-24 h-24 mb-5">
                  <div className="w-24 h-24 rounded-full overflow-hidden border border-neutral-800 animate-pop-in">
                    {avatarStyle ? (
                      <img
                        src={avatarUrl(avatarStyle, avatarSeed)}
                        alt="Your avatar"
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full bg-neutral-900 flex items-center justify-center">
                        <span className="text-xl font-semibold text-neutral-300">{getInitials(name)}</span>
                      </div>
                    )}
                  </div>
                  <div className="absolute -bottom-1 -right-1 w-8 h-8 rounded-full bg-emerald-500 flex items-center justify-center border-2 border-black">
                    <CheckCircle2 className="w-4 h-4 text-black" />
                  </div>
                </div>

                <h2 className="text-2xl font-bold tracking-tight mb-2">Welcome, {name}!</h2>
                <p className="text-sm text-neutral-400 mb-6">Registered successfully.</p>

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
