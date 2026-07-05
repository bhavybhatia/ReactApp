import { useEffect, useState, useCallback } from "react";
import { api } from "./api";
import "./App.css";

const PRIORITIES = ["low", "medium", "high"];
const STATUSES = ["todo", "in_progress", "done"];

function StatusBadge({ status }) {
  return <span className={`badge badge-${status}`}>{status.replace("_", " ")}</span>;
}

function PriorityBadge({ priority }) {
  return <span className={`chip chip-${priority}`}>{priority}</span>;
}

function TaskForm({ onCreate }) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState("medium");
  const [category, setCategory] = useState("general");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      await onCreate({ title, description, priority, category });
      setTitle("");
      setDescription("");
      setPriority("medium");
      setCategory("general");
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form className="task-form" onSubmit={handleSubmit}>
      <h2>New Task</h2>
      {error && <div className="error">{error}</div>}
      <input
        placeholder="Title"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        required
      />
      <textarea
        placeholder="Description (optional)"
        value={description}
        onChange={(e) => setDescription(e.target.value)}
        rows={2}
      />
      <div className="form-row">
        <label>
          Priority
          <select value={priority} onChange={(e) => setPriority(e.target.value)}>
            {PRIORITIES.map((p) => (
              <option key={p} value={p}>{p}</option>
            ))}
          </select>
        </label>
        <label>
          Category
          <input
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="general"
          />
        </label>
      </div>
      <button type="submit" disabled={submitting}>
        {submitting ? "Adding..." : "Add Task"}
      </button>
    </form>
  );
}

function TaskItem({ task, onUpdateStatus, onDelete }) {
  return (
    <li className="task-item">
      <div className="task-main">
        <div className="task-title-row">
          <strong>{task.title}</strong>
          <PriorityBadge priority={task.priority} />
          <StatusBadge status={task.status} />
        </div>
        {task.description && <p className="task-desc">{task.description}</p>}
        <span className="task-category">#{task.category}</span>
      </div>
      <div className="task-actions">
        <select
          value={task.status}
          onChange={(e) => onUpdateStatus(task.id, e.target.value)}
        >
          {STATUSES.map((s) => (
            <option key={s} value={s}>{s.replace("_", " ")}</option>
          ))}
        </select>
        <button className="danger" onClick={() => onDelete(task.id)}>
          Delete
        </button>
      </div>
    </li>
  );
}

function StatsPanel({ stats }) {
  if (!stats) return null;
  return (
    <div className="stats-panel">
      <h2>Stats</h2>
      <p className="stats-total">{stats.total} total tasks</p>
      <div className="stats-grid">
        <div>
          <h4>By status</h4>
          {Object.entries(stats.by_status).map(([k, v]) => (
            <div key={k} className="stats-row">
              <span>{k.replace("_", " ")}</span>
              <span>{v}</span>
            </div>
          ))}
        </div>
        <div>
          <h4>By priority</h4>
          {Object.entries(stats.by_priority).map(([k, v]) => (
            <div key={k} className="stats-row">
              <span>{k}</span>
              <span>{v}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function App() {
  const [tasks, setTasks] = useState([]);
  const [stats, setStats] = useState(null);
  const [statusFilter, setStatusFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [apiOnline, setApiOnline] = useState(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const filters = statusFilter ? { status: statusFilter } : {};
      const [taskList, statsData] = await Promise.all([
        api.listTasks(filters),
        api.getStats(),
      ]);
      setTasks(taskList);
      setStats(statsData);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    api.health().then(() => setApiOnline(true)).catch(() => setApiOnline(false));
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  async function handleCreate(task) {
    await api.createTask(task);
    await refresh();
  }

  async function handleUpdateStatus(id, status) {
    await api.updateTask(id, { status });
    await refresh();
  }

  async function handleDelete(id) {
    await api.deleteTask(id);
    await refresh();
  }

  return (
    <div className="app">
      <header>
        <h1>Task Manager</h1>
        <span className={`api-status ${apiOnline ? "online" : "offline"}`}>
          {apiOnline === null ? "checking API..." : apiOnline ? "API online" : "API offline"}
        </span>
      </header>

      <main>
        <section className="left-col">
          <TaskForm onCreate={handleCreate} />
          <StatsPanel stats={stats} />
        </section>

        <section className="right-col">
          <div className="filter-row">
            <h2>Tasks</h2>
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="">All statuses</option>
              {STATUSES.map((s) => (
                <option key={s} value={s}>{s.replace("_", " ")}</option>
              ))}
            </select>
          </div>

          {error && <div className="error">{error}</div>}
          {loading ? (
            <p>Loading...</p>
          ) : tasks.length === 0 ? (
            <p className="empty">No tasks yet.</p>
          ) : (
            <ul className="task-list">
              {tasks.map((task) => (
                <TaskItem
                  key={task.id}
                  task={task}
                  onUpdateStatus={handleUpdateStatus}
                  onDelete={handleDelete}
                />
              ))}
            </ul>
          )}
        </section>
      </main>
    </div>
  );
}
