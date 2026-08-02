# Sol Luna README “Control Orbit” Redesign

## Objective

Replace the current workshop-style README presentation with a project-native,
cost-first visual story. A first-time visitor should understand the following
without scrolling far:

1. Sol is the single controller.
2. Luna Max executes bounded tasks, including parallel tasks with disjoint
   ownership.
3. Evidence returns to Sol for review before delivery.
4. Typical suitable routed tasks are estimated to save about 59%.

The redesign applies the workflow and quality bar from
`oil-oil/beautify-github-readme` without copying its house style or marketing
copy.

## Mode and Release Boundary

- Mode: whole-README visual refresh with targeted information-architecture
  changes.
- Languages: Simplified Chinese remains the default `README.md`; English stays
  in `README.en.md` with matching structure and visuals.
- Preview gate: create and inspect a local GitHub-width preview before replacing
  README embeds or publishing changes.
- Publishing: do not push or merge until the user approves the rendered preview.
- Content boundary: preserve verified capabilities, cost caveats, platform
  limits, license information, and the existing LINUX DO thanks.

## Project Story

```text
Audience: Codex users and developers running complex multi-step repository work
One-sentence value: Sol plans, assigns, and reviews while Luna Max executes bounded work
Primary proof: task ownership, evidence return, and Sol PASS/FIX/BLOCKED review
First successful action: validate and install the Skill, then invoke $sol-luna
Visual theme: a precise control orbit with one Sol control core and multiple Luna workers
```

## Selected Direction

Use a pure-SVG “Control Orbit” system. The design is deterministic,
GitHub-safe, editable, lightweight, and directly expresses the orchestration
mechanism. Generated characters, space scenery, and photographic material are
excluded because they would add decoration without improving technical proof.

### Visual System

```text
Palette:
  background: #0B1020
  foreground: #F7F3E8
  Sol primary: #FF6B3D
  Luna accent: #65D6C4
  evidence accent: #8FA7FF
  muted: #9AA6B8
Typography:
  display/body: -apple-system, BlinkMacSystemFont, Segoe UI, PingFang SC, sans-serif
  metadata: ui-monospace, SFMono-Regular, Menlo, monospace
Shape:
  24-unit outer radius, 2-unit structural strokes, 8-unit spacing rhythm
Motif:
  one solar control core, lunar worker nodes, outbound task paths, inbound evidence paths
Composition:
  dark technical control plane with restrained orbital geometry
```

The Sun/Moon motif must communicate ownership and review, not serve as generic
space decoration. Sol is always singular and visually dominant. Luna nodes may
be multiple, but their task paths must remain independent. Evidence paths must
return to Sol.

## Hero Design

Create one `1200 × 420` SVG hero with its own dark background. Use an integrated
composition rather than a title placed above a separate diagram.

The hero contains:

- `SOL / LUNA` as the project title;
- a concise Chinese or English value statement;
- the prominent but qualified claim `普通任务约节省 59%` / `~59% estimated
  savings on suitable routine tasks`;
- one Sol control core;
- three disjoint Luna worker nodes representing bounded parallel execution;
- task packets travelling outward and FILES / DIFF / TEST evidence travelling
  back;
- a compact `PLAN → EXECUTE → REVIEW` process cue.

The title and proof share one grid. The hero must still communicate the project
if the surrounding Markdown is not visible. The 59% claim must include an
`estimated`/`估算` qualifier in the asset or immediately adjacent Markdown.

## Supporting Visual

Replace the current four equally prominent illustrations with one compact
`1200 × 520` control-plane explainer:

- lane 1: Direct, with no delegation;
- lane 2: Sol-only, with planning/review but no worker;
- lane 3: Sol → Luna, with bounded task packets and evidence return;
- ownership callout: one file, one owner;
- review result: PASS / FIX / BLOCKED.

The explainer must not repeat the hero. Its job is to clarify routing and safety
after the hero has established identity and value.

Section transitions should primarily use Markdown headings. Do not create a
large SVG for every section. Small project-native section bars are permitted
only if the preview needs stronger pacing.

## README Information Architecture

Use this order in both languages:

1. Language switch.
2. Integrated hero.
3. One short paragraph defining the Skill and qualifying the 59% estimate.
4. Proof/control-plane explainer.
5. Sixty-second install and first invocation.
6. Routing choices: Direct, Sol-only, Sol → Luna.
7. Reliability: model identity, write ownership, evidence, correction limits.
8. Cost model, formula, scenarios, and evidence boundaries.
9. Platform support and lifecycle commands.
10. Real-project routing sample and limitations.
11. Prior art, license, contribution information, and Thanks.

Detailed price tables and platform matrices remain searchable Markdown. Commands
must never exist only inside an image. Repeated explanations of the controller
relationship should be consolidated.

## Assets and Source Layout

Use project-owned paths:

```text
docs/assets/readme/
├── hero-zh.svg
├── hero-en.svg
├── control-plane-zh.svg
└── control-plane-en.svg
```

The Chinese and English assets share geometry and palette but use separately
fitted text. Do not embed raster images, remote fonts, scripts, `foreignObject`,
or remote resources.

The current `docs/assets/sol-luna-*.svg` files remain untouched until the new
preview is approved. After approval and README replacement, remove superseded
assets only if no repository reference remains.

## Preview and Verification

Before asking for visual approval:

1. Render every SVG locally.
2. Inspect at approximately 900 CSS pixels and 360 CSS pixels.
3. Verify Chinese and English text is not clipped.
4. Verify required diagram text is at least 20 SVG units and supporting labels
   are at least 18 SVG units.
5. Render a local README-like page showing the hero, first paragraph,
   control-plane explainer, and quick start in GitHub content width.
6. Run the bundled `beautify-github-readme` audit against both READMEs after
   embedding is approved.
7. Run repository README tests, validation scripts, and Git whitespace checks.

Acceptance criteria:

- The first screen answers what the project is, what Sol and Luna do, and why a
  user should care.
- Removing the repository name would not make the hero suitable for an
  unrelated AI project.
- Sol is visibly the single controller and Luna is visibly an execution worker.
- Parallel execution is shown only for disjoint work.
- Evidence clearly returns to Sol before PASS/FIX/BLOCKED.
- The 59% claim stays prominent and explicitly estimated.
- The design remains legible on GitHub light and dark surroundings.
- README text remains searchable, commands copyable, and claims unchanged in
  meaning.

## Explicit Non-Goals

- No generic astronaut, glowing brain, or cinematic space poster.
- No animated GIF in this iteration.
- No dashboard, website-style navigation, or rasterized full README.
- No changes to Skill runtime behavior, agents, installers, or tests unrelated
  to README presentation.
- No commit to `main`, push, release, or external showcase submission before
  explicit approval.
