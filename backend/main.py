"""
FastAPI backend for the Task Manager app.

Endpoints:
  GET    /api/health              -> health check
  GET    /api/tasks                -> list tasks (optional ?status= & ?priority= filters)
  POST   /api/tasks                -> create a task
  GET    /api/tasks/{task_id}      -> get a single task
  PUT    /api/tasks/{task_id}      -> update a task
  DELETE /api/tasks/{task_id}      -> delete a task
  GET    /api/stats                -> aggregate stats about tasks
  GET    /api/categories           -> list distinct categories in use
"""

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Task Manager API", version="1.0.0")

# Allow the React dev server (and any origin, for simplicity of this demo) to call the API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class Status(str, Enum):
    todo = "todo"
    in_progress = "in_progress"
    done = "done"


class TaskBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str = ""
    priority: Priority = Priority.medium
    status: Status = Status.todo
    category: str = "general"


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    priority: Optional[Priority] = None
    status: Optional[Status] = None
    category: Optional[str] = None


class Task(TaskBase):
    id: str
    created_at: datetime
    updated_at: datetime


# In-memory store. Restarting the server resets the data.
tasks_db: dict[str, Task] = {}


def _seed_data() -> None:
    seed = [
        TaskCreate(title="Design database schema", priority=Priority.high, category="backend"),
        TaskCreate(title="Build login page", priority=Priority.medium, category="frontend"),
        TaskCreate(title="Write API docs", priority=Priority.low, category="docs", status=Status.in_progress),
    ]
    for item in seed:
        task_id = str(uuid4())
        now = datetime.utcnow()
        tasks_db[task_id] = Task(id=task_id, created_at=now, updated_at=now, **item.model_dump())


_seed_data()


@app.get("/api/health")
def health_check():
    return {"status": "ok", "time": datetime.utcnow().isoformat()}


@app.get("/api/tasks", response_model=list[Task])
def list_tasks(
    status: Optional[Status] = Query(None, description="Filter by status"),
    priority: Optional[Priority] = Query(None, description="Filter by priority"),
    category: Optional[str] = Query(None, description="Filter by category"),
):
    results = list(tasks_db.values())
    if status is not None:
        results = [t for t in results if t.status == status]
    if priority is not None:
        results = [t for t in results if t.priority == priority]
    if category is not None:
        results = [t for t in results if t.category.lower() == category.lower()]
    return sorted(results, key=lambda t: t.created_at, reverse=True)


@app.post("/api/tasks", response_model=Task, status_code=201)
def create_task(payload: TaskCreate):
    task_id = str(uuid4())
    now = datetime.utcnow()
    task = Task(id=task_id, created_at=now, updated_at=now, **payload.model_dump())
    tasks_db[task_id] = task
    return task


@app.get("/api/tasks/{task_id}", response_model=Task)
def get_task(task_id: str):
    task = tasks_db.get(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@app.put("/api/tasks/{task_id}", response_model=Task)
def update_task(task_id: str, payload: TaskUpdate):
    task = tasks_db.get(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    update_data = payload.model_dump(exclude_unset=True)
    updated = task.model_copy(update={**update_data, "updated_at": datetime.utcnow()})
    tasks_db[task_id] = updated
    return updated


@app.delete("/api/tasks/{task_id}", status_code=204)
def delete_task(task_id: str):
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    del tasks_db[task_id]
    return None


@app.get("/api/stats")
def get_stats():
    all_tasks = list(tasks_db.values())
    total = len(all_tasks)
    by_status = {s.value: len([t for t in all_tasks if t.status == s]) for s in Status}
    by_priority = {p.value: len([t for t in all_tasks if t.priority == p]) for p in Priority}
    return {
        "total": total,
        "by_status": by_status,
        "by_priority": by_priority,
    }


@app.get("/api/categories")
def get_categories():
    categories = sorted({t.category for t in tasks_db.values()})
    return {"categories": categories}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
