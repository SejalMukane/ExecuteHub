// Minimal typings for @rails/actioncable (the package ships without .d.ts).
declare module "@rails/actioncable" {
  export interface Subscription {
    unsubscribe(): void;
    connected(): void;
    disconnected(): void;
  }

  export interface Subscriptions {
    create(
      channel: Record<string, unknown>,
      mixin: {
        received?: (data: unknown) => void;
        connected?: () => void;
        disconnected?: () => void;
      }
    ): Subscription;
  }

  export interface Cable {
    subscriptions: Subscriptions;
    disconnect(): void;
  }

  export function createConsumer(url?: string): Cable;
}
