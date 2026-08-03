"use client";

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  useState,
} from "react";
import { toast } from "sonner";
import { useAuth } from "@/context/AuthContext";
import {
  ActivityEvent,
  ConnectionState,
  RealtimeMessage,
  RunProgressEvent,
  WorkerEvent,
  disconnectCable,
  subscribeDashboard,
  subscribeQueue,
  subscribeWorkers,
} from "@/lib/realtime";

interface RealtimeState {
  metrics: RealtimeMessage & { type: "metrics_updated" } | null;
  queue: RealtimeMessage & { type: "queue_updated" } | null;
  workers: WorkerEvent[];
  testRuns: Record<number, RunProgressEvent>;
  activities: ActivityEvent[];
  connectionState: ConnectionState;
}

type Action =
  | { type: "SET_CONNECTION"; state: ConnectionState }
  | { type: "WORKER_EVENT"; payload: WorkerEvent }
  | { type: "QUEUE_UPDATE"; payload: RealtimeMessage & { type: "queue_updated" } }
  | { type: "METRICS_UPDATE"; payload: RealtimeMessage & { type: "metrics_updated" } }
  | { type: "RUN_PROGRESS"; payload: RunProgressEvent }
  | { type: "ADD_ACTIVITY"; payload: ActivityEvent };

function notify(text: string, kind: ActivityEvent["type"]) {
  if (kind === "success") toast.success(text);
  else if (kind === "error") toast.error(text);
  else if (kind === "warning") toast.warning(text);
  else toast.info(text);
}

function reducer(state: RealtimeState, action: Action): RealtimeState {
  switch (action.type) {
    case "SET_CONNECTION":
      return { ...state, connectionState: action.state };
    case "WORKER_EVENT": {
      const workers = state.workers.filter(
        (w) => w.worker_name !== action.payload.worker_name
      );
      const index = workers.findIndex(
        (w) => w.worker_name > action.payload.worker_name
      );
      if (index === -1) {
        workers.push(action.payload);
      } else {
        workers.splice(index, 0, action.payload);
      }
      return { ...state, workers };
    }
    case "QUEUE_UPDATE":
      return { ...state, queue: action.payload };
    case "METRICS_UPDATE":
      return { ...state, metrics: action.payload };
    case "RUN_PROGRESS": {
      return {
        ...state,
        testRuns: {
          ...state.testRuns,
          [action.payload.id]: action.payload,
        },
      };
    }
    case "ADD_ACTIVITY": {
      const activities = [action.payload, ...state.activities].slice(0, 100);
      return { ...state, activities };
    }
    default:
      return state;
  }
}

const initialState: RealtimeState = {
  metrics: null,
  queue: null,
  workers: [],
  testRuns: {},
  activities: [],
  connectionState: "connecting",
};

interface RealtimeContextValue extends RealtimeState {
  reconnect: () => void;
}

const RealtimeContext = createContext<RealtimeContextValue | undefined>(
  undefined
);

export { RealtimeContext };

function activityId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function workerEventText(
  type: RealtimeMessage["type"],
  worker: WorkerEvent
): string {
  switch (type) {
    case "worker_registered":
      return `${worker.worker_name} registered`;
    case "worker_online":
      return `${worker.worker_name} is online`;
    case "worker_offline":
      return `${worker.worker_name} went offline`;
    case "worker_heartbeat":
      return `${worker.worker_name} heartbeat`;
    default:
      return `${worker.worker_name} updated`;
  }
}

function eventType(
  type: RealtimeMessage["type"]
): ActivityEvent["type"] {
  switch (type) {
    case "job_completed":
    case "test_run_completed":
    case "worker_online":
    case "worker_registered":
    case "artifacts_uploaded":
      return "success";
    case "job_failed":
    case "worker_offline":
    case "execution_finished":
      return "error";
    case "job_started":
    case "test_run_started":
      return "info";
    case "job_created":
    case "queue_updated":
    case "metrics_updated":
    case "worker_heartbeat":
    case "test_run_progress_updated":
    default:
      return "info";
  }
}

export function RealtimeProvider({ children }: { children: React.ReactNode }) {
  const { token } = useAuth();
  const [state, dispatch] = useReducer(reducer, initialState);
  const [connectionState, setConnectionState] =
    useState<ConnectionState>("connecting");
  const connectionStateRef = useRef<ConnectionState>("connecting");

  useEffect(() => {
    connectionStateRef.current = connectionState;
  }, [connectionState]);

  const onConnectionChange = useCallback((state: ConnectionState) => {
    setConnectionState(state);
    dispatch({ type: "SET_CONNECTION", state });
  }, []);

  const onMessage = useCallback((message: RealtimeMessage) => {
    switch (message.type) {
      case "worker_registered":
      case "worker_heartbeat":
      case "worker_online":
      case "worker_offline":
        dispatch({ type: "WORKER_EVENT", payload: message.worker });
        dispatch({
          type: "ADD_ACTIVITY",
          payload: {
            id: activityId(),
            text: workerEventText(message.type, message.worker),
            type: eventType(message.type),
            timestamp: new Date().toISOString(),
          },
        });
        if (message.type === "worker_offline") {
          notify(`${message.worker.worker_name} went offline`, "error");
        } else if (message.type === "worker_online" || message.type === "worker_registered") {
          notify(`${message.worker.worker_name} is ${message.type === "worker_registered" ? "registered" : "online"}`, "success");
        }
        break;
      case "queue_updated":
        dispatch({ type: "QUEUE_UPDATE", payload: message });
        break;
      case "metrics_updated":
        dispatch({ type: "METRICS_UPDATE", payload: message });
        break;
      case "test_run_started":
      case "test_run_progress_updated":
      case "test_run_completed":
        dispatch({ type: "RUN_PROGRESS", payload: message.test_run });
        dispatch({
          type: "ADD_ACTIVITY",
          payload: {
            id: activityId(),
            text:
              message.type === "test_run_started"
                ? `Test Run #${message.test_run.id} started`
                : message.type === "test_run_completed"
                ? `Test Run #${message.test_run.id} completed (${message.test_run.status})`
                : `Test Run #${message.test_run.id} progress ${message.test_run.progress_percentage}%`,
            type: eventType(message.type),
            timestamp: new Date().toISOString(),
          },
        });
        if (message.type === "test_run_started") {
          notify(`Test Run #${message.test_run.id} started`, "info");
        } else if (message.type === "test_run_completed") {
          notify(
            `Test Run #${message.test_run.id} completed (${message.test_run.status})`,
            message.test_run.status === "completed" ? "success" : "error"
          );
        }
        break;
      case "job_started":
      case "job_completed":
      case "job_failed":
      case "job_created":
        dispatch({
          type: "ADD_ACTIVITY",
          payload: {
            id: activityId(),
            text:
              message.type === "job_started"
                ? `${message.job.worker_id ?? "Worker"} started Job #${message.job.id}`
                : message.type === "job_completed"
                ? `Job #${message.job.id} completed`
                : message.type === "job_failed"
                ? `Job #${message.job.id} failed`
                : `Job #${message.job.id} created`,
            type: eventType(message.type),
            timestamp: new Date().toISOString(),
          },
        });
        if (message.type === "job_failed") {
          notify(`Job #${message.job.id} failed`, "error");
        } else if (message.type === "job_completed") {
          notify(`Job #${message.job.id} completed`, "success");
        }
        break;
      case "artifacts_uploaded":
        dispatch({
          type: "ADD_ACTIVITY",
          payload: {
            id: activityId(),
            text: `Artifacts uploaded for Job #${message.artifacts.job_id} (${message.artifacts.artifact_count})`,
            type: "success",
            timestamp: new Date().toISOString(),
          },
        });
        notify(`Artifacts ready for Job #${message.artifacts.job_id}`, "success");
        break;
      case "execution_finished":
        dispatch({
          type: "ADD_ACTIVITY",
          payload: {
            id: activityId(),
            text: `Execution finished for Test Run #${message.test_run_id}`,
            type: "success",
            timestamp: new Date().toISOString(),
          },
        });
        break;
    }
  }, []);

  const reconnect = useCallback(() => {
    if (!token) return;
    disconnectCable(token);
    setConnectionState("connecting");
  }, [token]);

  useEffect(() => {
    if (!token) return;

    setConnectionState("connecting");
    const dashboard = subscribeDashboard(
      token,
      onMessage,
      onConnectionChange
    );
    const queue = subscribeQueue(token, onMessage, onConnectionChange);
    const workers = subscribeWorkers(token, onMessage, onConnectionChange);

    return () => {
      dashboard.unsubscribe();
      queue.unsubscribe();
      workers.unsubscribe();
    };
  }, [token, onMessage, onConnectionChange]);

  const value = useMemo(
    () => ({ ...state, connectionState, reconnect }),
    [state, connectionState, reconnect]
  );

  return (
    <RealtimeContext.Provider value={value}>{children}</RealtimeContext.Provider>
  );
}

export function useRealtime() {
  const context = useContext(RealtimeContext);
  if (!context) {
    throw new Error("useRealtime must be used within a RealtimeProvider");
  }
  return context;
}

export function useDashboard() {
  const { metrics, queue, workers, testRuns, activities, connectionState } =
    useRealtime();
  return {
    metrics: metrics?.metrics ?? null,
    queue: queue?.queue ?? metrics?.queue ?? null,
    workers,
    testRuns,
    activities,
    connectionState,
  };
}

export function useWorkers() {
  const { workers, connectionState } = useRealtime();
  return { workers, connectionState };
}

export function useQueue() {
  const { queue, connectionState } = useRealtime();
  return { queue: queue?.queue ?? null, connectionState };
}

export function useConnectionState() {
  return useRealtime().connectionState;
}
