export function createConsumer() {
  return {
    subscriptions: {
      create: () => ({
        unsubscribe: jest.fn(),
      }),
    },
    disconnect: jest.fn(),
    connection: { monitor: { state: "connected" } },
  };
}
