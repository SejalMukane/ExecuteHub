export const User = {};

export const api = {
  me: jest.fn().mockResolvedValue({ user: { id: 1, email: "test@example.com" } }),
};
