"use client";

import React, { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, BarChart3 } from "lucide-react";
import DashboardShell from "@/components/DashboardShell";
import AnalyticsDashboard from "@/components/AnalyticsDashboard";
import { useAuth } from "@/context/AuthContext";
import { api, AnalyticsResponse } from "@/lib/api";

const DAY_RANGES = [7, 14, 30, 90];

export default function AnalyticsPage() {
  const router = useRouter();
  const { token, loading } = useAuth();
  const [days, setDays] = useState(30);
  const [data, setData] = useState<AnalyticsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [fetching, setFetching] = useState(true);

  useEffect(() => {
    if (!loading && !token) router.replace("/login");
  }, [loading, token, router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;
    setFetching(true);

    const load = async () => {
      try {
        const res = await api.getAnalytics(token, days);
        if (!cancelled) {
          setData(res);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : "Failed to load analytics.");
      } finally {
        if (!cancelled) setFetching(false);
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, [token, days]);

  if (loading || !token) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-500" />
      </div>
    );
  }

  return (
    <DashboardShell active="analytics">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <BarChart3 className="w-6 h-6 text-neutral-500" />
          <h1 className="text-2xl font-bold tracking-tight">Analytics</h1>
        </div>
        <div className="inline-flex items-center gap-1 rounded-lg border border-neutral-800 p-1">
          {DAY_RANGES.map((range) => (
            <button
              key={range}
              onClick={() => setDays(range)}
              className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                days === range ? "bg-white text-black" : "text-neutral-400 hover:text-white"
              }`}
            >
              {range}d
            </button>
          ))}
        </div>
      </div>

      <AnalyticsDashboard data={data} loading={fetching} error={error} title="" />
    </DashboardShell>
  );
}
