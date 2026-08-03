"use client";

import { useCallback, useEffect, useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { api, Job, TestRun, TestRunProgress } from "@/lib/api";
import {
  ConnectionState,
  JobEvent,
  RealtimeMessage,
  subscribeJobs,
  subscribeTestRun,
} from "@/lib/realtime";

export function useTestRun(runId: number) {
  const { token } = useAuth();
  const [run, setRun] = useState<TestRun | null>(null);
  const [progress, setProgress] = useState<TestRunProgress | null>(null);
  const [connectionState, setConnectionState] =
    useState<ConnectionState>("connecting");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    const load = async () => {
      try {
        const [runRes, progressRes] = await Promise.all([
          api.getTestRun(token, runId),
          api.getTestRunProgress(token, runId),
        ]);
        if (cancelled) return;
        setRun(runRes.test_run);
        setProgress(progressRes.test_run);
      } catch (err) {
        if (!cancelled)
          setError(
            err instanceof Error ? err.message : "Failed to load test run."
          );
      }
    };

    load();

    return () => {
      cancelled = true;
    };
  }, [token, runId]);

  const updateJob = useCallback((jobEvent: JobEvent) => {
    setRun((prev) => {
      if (!prev || prev.id !== jobEvent.test_run_id) return prev;
      const jobs = prev.jobs?.map((job) =>
        job.id === jobEvent.id
          ? {
              ...job,
              status: jobEvent.status as Job["status"],
              worker_id: jobEvent.worker_id,
              started_at: jobEvent.started_at,
              finished_at: jobEvent.finished_at,
              retry_count: jobEvent.retry_count,
              container_id: jobEvent.container_id,
            }
          : job
      );
      return { ...prev, jobs };
    });
  }, []);

  const onMessage = useCallback(
    (message: RealtimeMessage) => {
      if (
        message.type === "test_run_started" ||
        message.type === "test_run_progress_updated" ||
        message.type === "test_run_completed"
      ) {
        setProgress((prev) => {
          const next = message.test_run as unknown as TestRunProgress;
          if (!prev || next.id === prev.id) return next;
          return prev;
        });
      } else if (
        message.type === "job_started" ||
        message.type === "job_completed" ||
        message.type === "job_failed" ||
        message.type === "job_created"
      ) {
        updateJob(message.job);
      }
    },
    [updateJob]
  );

  useEffect(() => {
    if (!token) return;
    const runSub = subscribeTestRun(
      token,
      runId,
      onMessage,
      setConnectionState
    );
    const jobsSub = subscribeJobs(token, onMessage, setConnectionState);
    return () => {
      runSub.unsubscribe();
      jobsSub.unsubscribe();
    };
  }, [token, runId, onMessage]);

  const live = progress ?? run;

  return {
    run,
    progress: live,
    connectionState,
    error,
    jobs: run?.jobs ?? [],
  };
}

export function useRunProgressEvent(runId: number | null) {
  const [run, setRun] = useState<TestRunProgress | null>(null);
  const { token } = useAuth();

  useEffect(() => {
    if (!token || !runId) return;
    const sub = subscribeTestRun(token, runId, (message) => {
      if (
        message.type === "test_run_started" ||
        message.type === "test_run_progress_updated" ||
        message.type === "test_run_completed"
      ) {
        setRun(message.test_run as unknown as TestRunProgress);
      }
    });
    return () => sub.unsubscribe();
  }, [token, runId]);

  return run;
}
