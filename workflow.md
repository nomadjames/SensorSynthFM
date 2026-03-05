# SensorSynth FM — Workflow Plan

Updated: February 19, 2026

---

## Tool Landscape

### Xcode 26.3 + Claude Agent
**Role**: Primary implementation engine for Swift/SwiftUI/AudioKit code.

What it can do:
- Read and modify project files directly
- Build the project and report errors
- Run tests
- Take screenshots of SwiftUI Previews to verify UI work
- Access Apple developer documentation
- Operate autonomously on multi-step coding tasks

Best for:
- Writing and debugging Swift code (AudioEngine, FM oscillator, sensor integration)
- Resolving build errors and AudioKit linking issues with direct feedback
- Iterating on SwiftUI views with visual verification through Previews
- Any task where build-test-fix cycles matter

Setup: Xcode > Settings > Intelligence > Claude Agent (signed in via Claude.ai account).

Notes:
- Ships with Claude Opus 4.5 (v2.1.14); Opus 4.6 (v2.1.32) is available if updated
- MCP configuration requires absolute paths (Xcode sandboxes the agent environment)
- CLAUDE.md in the project root gives the agent project context and coding rules
- Always work on a branch when letting the agent make large changes

### Gemini 3.1 Pro (via Antigravity or Google AI Studio)
**Role**: Large-context research, review, and content generation.

Specs:
- 1M token input context (can hold the entire codebase plus documentation)
- 64K token output limit (can generate large files in a single pass)
- Multimodal: text, images, audio, video, PDFs, code
- 100MB file upload limit

Best for:
- Architectural review: feed entire codebase + Apple docs, ask design questions
- UI design reasoning: load design_guidelines.md + Apple HIG + mockup screenshots
- Long-form writing: Medium article, documentation passes, research writeups
- Second-opinion code review from a different model family
- Large-context Q&A about AudioKit, AVAudioEngine, CoreMotion, Vision framework

Access: Antigravity (preferred, already familiar) or Google AI Studio (aistudio.google.dev).

Notes:
- Antigravity is still in public preview with some reported stability issues
- AI Studio offers more raw control if Antigravity has problems
- Google One subscription provides access through both paths
- Good for tasks where you want a perspective outside the Claude model family

### Claude in Cowork (this tool)
**Role**: Project orchestration, documentation, deliverables, and research.

Best for:
- Maintaining project documentation (.md files, tasks.md, CLAUDE.md)
- Creating deliverables for the MS UX program (reports, presentations, spreadsheets)
- Web research (searching docs, finding solutions, reading articles)
- Browser-based tasks (Google Drive, AI Studio interaction if needed)
- Task tracking and sprint planning
- Preparing context bundles for the other tools

Cannot do:
- Directly control Xcode or Antigravity (desktop apps on your Mac)
- Build or run Swift code
- See SwiftUI Previews

---

## Task Routing Guide

When starting a task, use this to decide which tool handles it:

| Task Type | Primary Tool | Why |
|-----------|-------------|-----|
| Write Swift code | Xcode Claude Agent | Direct build/test feedback |
| Fix build errors | Xcode Claude Agent | Can see compiler output |
| Design SwiftUI views | Xcode Claude Agent + Gemini | Agent builds, Gemini reviews design logic |
| Architectural decisions | Gemini 3.1 Pro | Large context for docs + codebase |
| AudioKit/AVAudioEngine questions | Gemini 3.1 Pro | Feed full API docs into context |
| UI/UX design review | Gemini 3.1 Pro | Load HIG + design_guidelines.md + screenshots |
| Update project docs | Cowork | Direct file access to .md files |
| Medium article / writing | Gemini 3.1 Pro or Cowork | Gemini for drafts, Cowork for formatting |
| MS UX program deliverables | Cowork | Document creation skills (docx, pptx, etc.) |
| Research / web lookups | Cowork | Browser and search access |
| Sprint planning | Cowork | Tasks.md management |
| Code review (second opinion) | Gemini 3.1 Pro | Different model family perspective |

---

## Session Workflow

### Starting a session
1. Open Cowork. Reference tasks.md to see current sprint status.
2. Identify the next task and decide which tool handles it (see routing guide).
3. If implementation: open Xcode, use Claude Agent on a feature branch.
4. If research/design: open Antigravity or AI Studio with relevant context.
5. If documentation/planning: work directly in Cowork.

### During a session
- One task at a time (per tasks.md rules).
- If the Xcode agent makes changes, review diffs before committing.
- If Gemini provides architectural advice, bring key decisions back to Cowork for documentation.
- If switching tools mid-task, note where you left off.

### Ending a session
1. Commit any code changes (Xcode or terminal).
2. Update tasks.md with completed items and session notes.
3. Update CLAUDE.md if lessons were learned.
4. Note in session log what to do next.

---

## Cross-Tool Communication

Since the tools cannot talk to each other directly, James is the bridge.
The workflow for passing context between tools:

**Cowork to Xcode Agent**: Cowork prepares code snippets, architectural guidance,
or documentation. James pastes relevant context into the Xcode agent conversation
or updates CLAUDE.md (which the agent reads automatically).

**Xcode Agent to Cowork**: James reports build results, errors, or questions
back to Cowork. Copy-paste of error logs or code snippets works well.

**Cowork to Gemini (Antigravity)**: Cowork prepares context bundles (multiple
.md files combined, specific questions framed with context). James pastes into
Antigravity or uploads files.

**Gemini to Cowork**: James brings back Gemini's analysis or recommendations.
Cowork integrates into project docs or uses to inform next steps.

---

## Future Integration Possibilities

- **Xcode MCP Bridge**: Terminal-based agents can access Xcode Previews via
  `claude mcp add --transport stdio xcode -- xcrun mcpbridge`. This could
  tighten the Cowork-to-Xcode loop if needed.
- **Antigravity MCP**: Antigravity reportedly supports MCP, which could
  enable tool-to-tool communication. Worth exploring if the manual
  bridge becomes a bottleneck.
- **Gemini CLI in Xcode**: Can run Gemini as an alternative agent in Xcode
  via MCP for tasks where its large context is advantageous.

---

## Context for This Document
This workflow was designed for the SensorSynth FM project, an iPad FM synthesizer
with passive environment sensing. The project serves dual purposes: a shipping
App Store product and a design research artifact for James's MS UX program at
Kent State University (fall 2026 deadline). Tool choices reflect both the
technical needs of real-time audio development and the academic deliverable
requirements.
