# LeetTow — AI-Powered Coding Hints Chrome Extension

LeetTow is a Chrome extension that provides progressive, no-spoiler hints and similar problem recommendations for LeetCode and other coding platforms.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│    Frontend       │────▶│    Backend        │────▶│   AI Service     │
│  Chrome Extension │     │  Node.js + Express│     │  Node.js + OpenAI│
│  React popup      │     │  Port 3001        │     │  Port 5000       │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

### Services

| Service      | Port | Description                                      |
|-------------|------|--------------------------------------------------|
| `frontend/` | —    | React-based Chrome Extension (popup + content scripts) |
| `backend/`  | 3001 | Express API — orchestrates AI hints + recommendations |
| `ai-service/` | 5000 | OpenAI microservice — generates no-spoiler hints |

## Quick Start

### 1. Install Dependencies

```bash
cd ai-service && npm install
cd ../backend && npm install
cd ../frontend && npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env` in each service and fill in your values:

```bash
# ai-service/.env — set your OpenAI API key
OPENAI_API_KEY=sk-your-actual-key-here

# backend/.env — defaults work out of the box
# frontend/.env — defaults work out of the box
```

### 3. Start Services

```bash
# Terminal 1: AI Service
cd ai-service && npm start

# Terminal 2: Backend
cd backend && npm start
```

### 4. Build & Load Extension

```bash
cd frontend && npm run build
```

Then load the extension in Chrome:
1. Open `chrome://extensions/`
2. Enable **Developer mode** (top right)
3. Click **Load unpacked**
4. Select the `frontend/build` directory

## API Endpoints

### Backend (port 3001)

| Method | Endpoint              | Description                          |
|--------|-----------------------|--------------------------------------|
| GET    | `/api/health`         | Health check                         |
| POST   | `/api/problem/analyze`| Analyze a problem (hints + similar)  |

**POST /api/problem/analyze** request:
```json
{
  "title": "Two Sum",
  "difficulty": "Easy",
  "tags": ["Array", "Hash Table"]
}
```

Response:
```json
{
  "success": true,
  "data": {
    "problemTitle": "Two Sum",
    "hintLevels": ["hint 1", "hint 2", "hint 3"],
    "similarProblems": [
      { "title": "3Sum", "difficulty": "Medium", "link": "https://..." }
    ]
  }
}
```

### AI Service (port 5000)

| Method | Endpoint         | Description                    |
|--------|------------------|--------------------------------|
| GET    | `/health`        | Health check                   |
| POST   | `/generate-hint` | Generate 3 progressive hints   |

**POST /generate-hint** request:
```json
{
  "title": "Two Sum",
  "description": "...",
  "difficulty": "Easy"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "hintLevels": ["hint 1", "hint 2", "hint 3"]
  }
}
```

## Testing

### Verify APIs

```bash
# Backend health
curl http://localhost:3001/api/health

# AI service health
curl http://localhost:5000/health

# Analyze a problem
curl -X POST http://localhost:3001/api/problem/analyze \
  -H "Content-Type: application/json" \
  -d '{"title":"Two Sum","difficulty":"Easy","tags":["Array","Hash Table"]}'
```

### Test Extension

1. Navigate to any LeetCode problem page
2. Click the LeetTow extension icon
3. The popup should show:
   - Detected problem title and difficulty
   - "Show Hint" button (click for progressive hints)
   - Similar problems list

## Fallback Behavior

- If the AI service is unavailable or the API key is invalid, the system returns **difficulty-aware fallback hints** — the user always gets useful guidance
- The backend never throws errors to the frontend for AI failures
- The frontend shows a subtle error banner if the backend is unreachable, while still displaying fallback content