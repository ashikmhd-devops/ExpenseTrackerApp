<div align="center">

# ExpenseTracker

**A privacy-first, AI-powered expense tracker for macOS**
*Everything runs locally. No cloud. No subscriptions. No data leaves your Mac.*

[![Swift](https://github.com/ashikmhd-devops/ExpenseTrackerApp/actions/workflows/swift.yml/badge.svg)](https://github.com/ashikmhd-devops/ExpenseTrackerApp/actions/workflows/swift.yml)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![AI](https://img.shields.io/badge/AI-Ollama%20%7C%20llama3.2%20%7C%20llava-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

---

## What is this?

ExpenseTracker is a macOS app that turns the way you track money into a conversation. Instead of filling in forms, you just describe what you spent — in plain language. The app's local AI figures out the rest: amount, category, merchant, and date.

Drop in a receipt photo or a bank SMS screenshot, and the vision model reads it for you. Ask the AI advisor "where am I overspending?" and get a personalised answer grounded in your real data. Everything — the models, the database, the logic — runs entirely on your machine.

---

## Feature Overview

### Natural Language Expense Entry
Type the way you think. The app handles the parsing.

```
"spent 2000 on hospital for child yesterday"
"paid 8452 for car service last friday"
"Netflix subscription 199 on Feb 28th"
"Shell petrol 1800 this morning"
```

- Extracts **amount**, **merchant**, **category**, and **date** from free-form text
- Understands relative dates: *today, yesterday, last Monday, last Friday*, etc.
- Context-aware categorisation — "Shell" at ₹500 in the morning → **Food**; at ₹1800 in the afternoon → **Fuel**
- Always assumes the **most recent past** date when no year is specified
- Live preview card in the Quick Add sheet before saving

---

### Receipt & Document Scanning (Drag & Drop)
Drop any file onto the Expenses tab and the vision AI reads it.

| Supported input | Examples |
|---|---|
| Physical receipt photos | Restaurant bills, grocery slips |
| Bank SMS screenshots | "Rs.199.00 debited to NETFLIX COM" |
| UPI / IMPS debit alerts | HDFC, SBI, ICICI, PhonePe, Google Pay |
| PDF receipts | E-commerce invoices, utility bills |

**How it works:**
1. Drag a PDF or image anywhere onto the Expenses tab
2. A sparkle-animated processing card appears while `llava` reads the file
3. The confirm sheet opens pre-filled — review, edit any field, then save

VPA addresses are decoded intelligently:
`netflixupi.payu@hdfcbank` → **Netflix** · **Entertainment** · ₹199

---

### AI Spending Advisor (Chat Tab)
A dedicated conversational AI that knows your actual spending data.

- Proactively reviews your finances: *"I noticed you're spending 20% more on dining this month…"*
- Answers specific questions: *"Should I set a dining budget?"*, *"What's my biggest expense category?"*
- Suggests specific limits based on your real numbers
- Full multi-turn conversation with message history
- Typing indicator with animated dots while the model thinks
- Live **Ollama status dot** — green pulse when the local server is ready

---

### Natural Language Query Bar
Ask data questions directly in the Expenses tab.

- **Data queries** — "How much did I spend on Food this month?" → runs a real SQL query against your database
- **Conversational questions** — "Should I cut back on dining?" → automatically routes to the AI Advisor tab
- Auto-detects question intent using keyword matching

---

### Budget Tracking
- Set a monthly spending limit with the **Set Budget** button
- Live gauge shows spend progress: green → yellow → orange → red
- The "Spent This Month" amount dynamically changes colour to match the gauge
- Budget persists across app launches

---

### Expense Management
- **Card-style list** with pastel category icons, hover-reveal actions, and dark/light mode adaptive backgrounds
- **Edit** any expense — hover a row to reveal the pencil icon → opens a full edit sheet
- **Delete** individual expenses with confirmation (hover → trash icon)
- **Clear all** via toolbar with confirmation
- **Multi-select** with keyboard and mouse

---

### AI Insights (Sidebar)
- One-tap "Generate Insights" in the sidebar
- Gets 2–3 actionable observations about your category breakdown
- Displayed inline with an animated fade-in

---

## Tech Stack

| Component | Technology |
|---|---|
| Language | Swift 5.9 |
| UI Framework | SwiftUI (macOS 14+) |
| Database | SQLite via [GRDB](https://github.com/groue/GRDB.swift) |
| Text AI | [Ollama](https://ollama.com) — `llama3.2:latest` |
| Vision AI | Ollama — `llava:latest` |
| Chat API | Ollama `/api/chat` (multi-turn) |
| PDF rendering | PDFKit |
| CI | GitHub Actions + xcodebuild |

---

## Architecture

```
ExpenseTrackerApp/
├── Models/
│   ├── Expense.swift              # GRDB record, Codable, Identifiable
│   ├── ExpenseCategory.swift      # Enum with icon, pastel colour, and display helpers
│   ├── ChatMessage.swift          # AI chat message model
│   └── ReceiptImageHelper.swift   # PDF → NSImage → base64 JPEG conversion
│
├── Services/
│   ├── DatabaseService.swift      # SQLite CRUD + raw SQL execution via GRDB
│   └── OllamaService.swift        # All LLM calls:
│                                  #   • parseNaturalLanguageExpense  (llama3.2)
│                                  #   • generateInsights             (llama3.2)
│                                  #   • generateSQLQuery             (llama3.2)
│                                  #   • chat                         (llama3.2 /api/chat)
│                                  #   • extractExpenseFromReceipt    (llava)
│
├── ViewModels/
│   ├── AppViewModel.swift         # Central state: expenses, chat, receipt scanning, budget
│   └── QuickAddViewModel.swift    # Quick Add sheet parsing flow
│
└── Views/
    ├── MainDashboardView.swift    # TabView shell, budget editor, drop handling
    ├── ExpenseListView.swift      # Card list, hover actions, edit/delete
    ├── NLQueryView.swift          # Query bar with smart routing
    ├── AIChatView.swift           # Chat tab: bubbles, typing indicator, suggestion chips
    ├── QuickAddWidgetView.swift   # NL input sheet with live preview
    ├── EditExpenseView.swift      # Full-field edit sheet
    └── ReceiptScanViews.swift     # Drop overlay, sparkle card, confirm sheet
```

---

## Setup

### Prerequisites

| Requirement | Version |
|---|---|
| macOS | 14.0 Sonoma or later |
| Xcode | 15+ |
| [Ollama](https://ollama.com) | Latest |

### 1. Install models

```bash
# Text model (expense parsing, insights, chat, SQL)
ollama pull llama3.2

# Vision model (receipt and image scanning)
ollama pull llava
```

### 2. Start Ollama

```bash
ollama serve
```

> The app shows a green pulse dot in the AI Advisor tab when the server is reachable.

### 3. Build and run

```bash
git clone https://github.com/ashikmhd-devops/ExpenseTrackerApp.git
cd ExpenseTrackerApp
open ExpenseTrackerApp.xcodeproj
# Build & Run in Xcode (⌘R)
```

---

## Usage Guide

### Adding an expense
- Press **⌘N** or click **+ Add Expense** (bottom-right FAB)
- Type a natural language description and press Enter
- Review the parsed card, then click **Save**

### Scanning a receipt
- Drag a receipt image or bank SMS screenshot onto the **Expenses** tab
- Wait for the sparkle animation to finish
- Review and confirm the extracted fields

### Asking the AI
- Switch to the **AI Advisor** tab
- Click **Review My Spending** for a proactive analysis
- Or type any question: *"Am I spending too much on food?"*

### Setting a budget
- In the sidebar, click **Set Budget** next to the gauge
- Enter your monthly limit — the gauge and amount colour update immediately

### Querying your data
- Type a question in the search bar on the Expenses tab
- Data questions run live SQL: *"Total spent on Shopping this month"*
- Conversational questions auto-route to the AI Advisor tab

---

## Data & Privacy

All data is stored locally on your Mac:

```
~/Library/Application Support/<bundle-id>/expenses.sqlite
```

No analytics, no telemetry, no network requests except to `127.0.0.1:11434` (your local Ollama server).

---

## Contributing

Pull requests are welcome. For significant changes, open an issue first to discuss what you'd like to change.

---

<div align="center">

Built with SwiftUI · Powered by Ollama · Runs entirely on your Mac

</div>
