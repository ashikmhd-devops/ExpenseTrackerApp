# ExpenseTrackerApp

[![Swift](https://github.com/ashikmhd-devops/ExpenseTrackerApp/actions/workflows/swift.yml/badge.svg)](https://github.com/ashikmhd-devops/ExpenseTrackerApp/actions/workflows/swift.yml)
A macOS expense tracker that uses a local LLM (via Ollama) to parse natural language input into structured expense records.

## Features

- **Natural language input** — type things like "spent 2000 on hospital for child yesterday" or "paid 8452 for car service last friday" and the app extracts the amount, category, merchant, and date automatically
- **Local LLM** — uses Ollama (llama3.2) running on your machine; no data leaves your device
- **Relative date parsing** — resolves "yesterday", "last Monday", "last Friday", etc. to exact dates
- **Expense categories** — Food, Fuel, Shopping, Utilities, Entertainment, Travel, Health, Education, Vehicle, Miscellaneous
- **Monthly summary** — shows total spent in the current month on the dashboard
- **Delete & clear** — swipe to delete individual expenses or clear all at once

## Requirements

- macOS 13+
- [Ollama](https://ollama.com) installed and running locally
- `llama3.2` model pulled in Ollama

## Setup

1. Install Ollama and pull the model:
   ```bash
   ollama pull llama3.2
   ```

2. Make sure Ollama is running:
   ```bash
   ollama serve
   ```

3. Open `ExpenseTrackerApp.xcodeproj` in Xcode, build and run.

## Usage

- Click **+** in the toolbar to open the Quick Add sheet
- Type a natural language description of your expense and press Enter
- The app sends your input to the local Ollama model, which returns structured JSON
- The parsed expense is saved to a local SQLite database

## Architecture

| Layer | File | Responsibility |
|---|---|---|
| Model | `Expense.swift`, `ExpenseCategory.swift` | Data types, GRDB record conformance |
| Service | `DatabaseService.swift` | SQLite read/write via GRDB |
| Service | `OllamaService.swift` | LLM prompt construction and response parsing |
| ViewModel | `AppViewModel.swift` | Expense list state, add/delete/clear |
| ViewModel | `QuickAddViewModel.swift` | Quick add sheet state and parsing flow |
| View | `MainDashboardView.swift` | Navigation split view, monthly summary |
| View | `ExpenseListView.swift` | Expense list with swipe-to-delete and clear all |
| View | `QuickAddWidgetView.swift` | Natural language input sheet |

## Data Storage

Expenses are stored in a SQLite database at:
```
~/Library/Application Support/<bundle-id>/expenses.sqlite
```
