// Thin wrapper around the FastAPI endpoints.
// In dev, Vite proxies "/api" to http://localhost:8000 (see vite.config.js).
const BASE_URL = "/api";

async function request(path, options = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });

  if (!res.ok) {
    let detail = res.statusText;
    try {
      const body = await res.json();
      detail = body.detail || detail;
    } catch (_) {
      // ignore parse errors
    }
    throw new Error(detail);
  }

  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  health: () => request("/health"),

  listTasks: (filters = {}) => {
    const params = new URLSearchParams(filters).toString();
    return request(`/tasks${params ? `?${params}` : ""}`);
  },

  createTask: (task) =>
    request("/tasks", { method: "POST", body: JSON.stringify(task) }),

  getTask: (id) => request(`/tasks/${id}`),

  updateTask: (id, updates) =>
    request(`/tasks/${id}`, { method: "PUT", body: JSON.stringify(updates) }),

  deleteTask: (id) => request(`/tasks/${id}`, { method: "DELETE" }),

  getStats: () => request("/stats"),

  getCategories: () => request("/categories"),
};
