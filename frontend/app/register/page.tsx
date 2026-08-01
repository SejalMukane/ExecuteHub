"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowRight, Loader2 } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

export default function RegisterPage() {
  const router = useRouter();
  const { setAuth } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api.register(name, email, password, password);
      setAuth(res.user, res.token);
      router.push("/dashboard");
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

  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-white selection:text-black relative overflow-hidden flex flex-col">
      {/* Dot grid */}
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.03]"
        style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, white 1px, transparent 0)`,
          backgroundSize: "40px 40px",
        }}
      />

      {/* Ambient glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[400px] bg-neutral-800/20 rounded-full blur-3xl pointer-events-none" />

      <div className="relative z-10 flex-1 flex flex-col">
        {/* Header */}
        <header className="h-16 max-w-7xl mx-auto w-full px-6 flex items-center border-b border-neutral-900">
          <Link href="/" className="font-bold tracking-tight text-base hover:text-neutral-300 transition-colors">
            ExecuteHub
          </Link>
        </header>

        {/* Register form */}
        <main className="flex-1 flex items-center justify-center px-6">
          <div className="w-full max-w-sm">
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
                  placeholder="you@example.com"
                  className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
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
                  className="w-full px-3.5 py-2.5 text-sm rounded-md border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-neutral-600 focus:ring-1 focus:ring-neutral-600 transition-colors"
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
