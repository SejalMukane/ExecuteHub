"use client";

import React from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
} from "recharts";
import { Loader2 } from "lucide-react";
import { AnalyticsResponse } from "@/lib/api";

function formatDuration(ms: number | null): string {
  if (ms === null || ms === undefined) return "—";
  if (ms < 1000) return `${ms}ms`;
  const seconds = ms / 1000;
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m ${Math.round(seconds % 60)}s`;
}

function tooltipValue(ms: number | null) {
  return formatDuration(ms);
}

const tooltipStyle = {
  backgroundColor: "#0a0a0a",
  border: "1px solid #262626",
  borderRadius: "0.5rem",
  fontSize: "12px",
  color: "#d4d4d4",
};

function LineCard<T extends { date: string }>({
  title,
  data,
  dataKey,
  color,
  unit,
}: {
  title: string;
  data: T[];
  dataKey: string;
  color: string;
  unit?: "percent" | "duration";
}) {
  return (
    <div className="rounded-xl glass-panel p-5">
      <h3 className="text-sm font-semibold mb-4">{title}</h3>
      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={data} margin={{ top: 5, right: 10, left: -15, bottom: 0 }}>
          <CartesianGrid stroke="#262626" strokeDasharray="3 3" vertical={false} />
          <XAxis
            dataKey="date"
            stroke="#525252"
            fontSize={11}
            tickFormatter={(v: string) => v.slice(5)}
          />
          <YAxis
            stroke="#525252"
            fontSize={11}
            width={60}
            domain={unit === "percent" ? [0, 100] : ["auto", "auto"]}
            tickFormatter={(v: number) => (unit === "duration" ? `${Math.round(v / 1000)}s` : `${v}%`)}
          />
          <Tooltip
            contentStyle={tooltipStyle}
            formatter={(value: unknown) =>
              unit === "duration"
                ? [tooltipValue(typeof value === "number" ? value : null), "Duration"]
                : [`${value}%`, "Rate"]
            }
          />
          <Line
            type="monotone"
            dataKey={dataKey}
            stroke={color}
            strokeWidth={2}
            dot={false}
            name="Value"
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

export default function AnalyticsDashboard({
  data,
  loading,
  error,
  title,
}: {
  data: AnalyticsResponse | null;
  loading: boolean;
  error: string | null;
  title: string;
}) {
  if (loading) {
    return (
      <div className="rounded-xl glass-panel px-5 py-12 text-center">
        <Loader2 className="w-6 h-6 animate-spin text-neutral-600 mx-auto mb-3" />
        <p className="text-sm text-neutral-500">Loading analytics…</p>
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="rounded-xl glass-panel px-5 py-12 text-center">
        <p className="text-sm text-red-400">{error ?? "Analytics unavailable."}</p>
      </div>
    );
  }

  const { overview, history } = data;

  const stats = [
    { label: "Success Rate", value: `${overview.success_rate}%` },
    { label: "Failure Rate", value: `${overview.failure_rate}%` },
    { label: "Tests Executed", value: String(overview.tests_executed) },
    { label: "Passed", value: String(overview.tests_passed) },
    { label: "Failed", value: String(overview.tests_failed) },
    { label: "Skipped", value: String(overview.tests_skipped) },
    { label: "Flaky Tests", value: String(overview.flaky_test_count) },
    { label: "Retry Rate", value: `${overview.retry_rate}%` },
    { label: "Worker Utilization", value: `${overview.worker_utilization}%` },
    { label: "Avg Run Duration", value: formatDuration(overview.average_execution_duration_ms) },
    { label: "Avg Test Duration", value: formatDuration(overview.average_test_duration_ms) },
    { label: "Test Runs", value: `${overview.completed_test_runs}/${overview.total_test_runs}` },
  ];

  return (
    <div>
      {title && (
        <div className="mb-8">
          <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
        </div>
      )}

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 mb-6">
        {stats.map((stat) => (
          <div key={stat.label} className="rounded-xl glass-panel p-4">
            <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold">
              {stat.label}
            </p>
            <p className="text-2xl font-bold tracking-tight mt-1 tabular-nums">{stat.value}</p>
          </div>
        ))}
      </div>

      <div className="grid lg:grid-cols-2 gap-6 mb-6">
        <LineCard
          title="Success Rate Over Time"
          data={history.success_rate_over_time}
          dataKey="success_rate"
          color="#34d399"
          unit="percent"
        />
        <LineCard
          title="Failure Rate Over Time"
          data={history.failure_rate_over_time}
          dataKey="failure_rate"
          color="#f87171"
          unit="percent"
        />
        <LineCard
          title="Average Execution Duration"
          data={history.average_execution_duration.map((p) => ({
            ...p,
            average_execution_duration_ms: p.average_execution_duration_ms ?? 0,
          }))}
          dataKey="average_execution_duration_ms"
          color="#60a5fa"
          unit="duration"
        />
        <LineCard
          title="Tests Executed Per Day"
          data={history.tests_executed_per_day}
          dataKey="tests_executed"
          color="#a78bfa"
        />
      </div>

      {history.most_failing_tests.length > 0 && (
        <div className="grid lg:grid-cols-2 gap-6 mb-6">
          <div className="rounded-xl glass-panel p-5">
            <h3 className="text-sm font-semibold mb-4">Most Failing Tests</h3>
            <div className="space-y-3">
              {history.most_failing_tests.map((item) => (
                <div key={item.name}>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-neutral-300 font-mono text-xs truncate mr-3">{item.name}</span>
                    <span className="text-neutral-500 tabular-nums">{item.count}</span>
                  </div>
                  <div className="h-1.5 rounded-full bg-neutral-900 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-red-500"
                      style={{
                        width: `${Math.min(100, (item.count / Math.max(1, history.most_failing_tests[0].count)) * 100)}%`,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-xl glass-panel p-5">
            <h3 className="text-sm font-semibold mb-4">Most Failing Suites</h3>
            <div className="space-y-3">
              {history.most_failing_suites.map((item) => (
                <div key={item.name}>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-neutral-300 text-sm truncate mr-3">{item.name}</span>
                    <span className="text-neutral-500 tabular-nums">{item.count}</span>
                  </div>
                  <div className="h-1.5 rounded-full bg-neutral-900 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-amber-500"
                      style={{
                        width: `${Math.min(100, (item.count / Math.max(1, history.most_failing_suites[0].count)) * 100)}%`,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
