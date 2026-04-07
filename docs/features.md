# Trail Route Planner — Feature & UX Specification

> Tech-agnostic. This document describes what the app does and how it behaves, not how it is built.
> Use this as the acceptance checklist when evaluating any tech stack implementation.
>
> **Keep this document current.** Any time a feature changes, is added, or is removed during development, update this file to reflect the new behaviour before closing the task.

---

## App Overview

A mobile app for planning and saving trail runs. Users create routes on a map, view stats and elevation, and export routes as GPX files to a GPS watch or other device.

**Not in scope (current version):** live GPS tracking, turn-by-turn navigation, route following.
**Planned future:** sharing routes with other users.

**UI pattern:** single full-screen map with all controls, sheets, and modals overlaid on top. No tab bar. No side drawer.

---

## Screens & Surfaces

| Surface | Type | Trigger |
|---|---|---|
| Home Map | Full screen | App launch |
| Route List Sheet | Bottom sheet (always peeking) | Always visible on home map |
| Route Detail Modal | Floating modal | Tap a route on the map |
| Route Editor | Full screen | "New route" or "Edit" from list/modal |
| Editor Stats Sheet | Bottom sheet (on editor screen) | Always present in editor |
| Map Layer Popover | Popover | Layers icon |
| Search Modal | Fade-in modal | Search icon |
| Settings | Full screen | Gear icon |
| Sign In Sheet | Bottom sheet | "Sign in" in Settings |
| Downloaded Regions Sheet | Bottom sheet on map | "Downloaded Regions" in Settings |
| Bbox Selection | Full screen map | "+ Download region" |
| GPX Import Modal | Overlay modal | Import button in route list sheet |
| Delete Confirmation | Modal | Delete button in editor |
| Unsaved Changes Guard | Modal | Back with unsaved changes |
| Leave Confirmation | Modal | Back with unsaved changes in bbox screen |

---

## 1. Home Map Screen

### Persistent controls

| Position | Control | Action |
|---|---|---|
| Top-left | Gear icon | Navigate to Settings (full screen push) |
| Top-right, 1st | Layers icon | Open map layer popover |
| Top-right, 2nd | GPS / locate icon | Center map camera on current location |
| Top-right, 3rd | Search (magnifying glass) icon | Open search modal |
| Top-right, 4th | + (plus) icon | Start new route in editor |

### Map state (idle)
- All saved routes are drawn on the map simultaneously, each in its own route color.
- Routes are hidden only while the editor is open.

### Route List Sheet
- Always visible — handle peeks up from the bottom of the screen at all times.
- Two states: peeked (handle only) and fully open (no second snap point).
- See Section 3 for full layout.

---

## 2. Route Detail Modal

**Trigger:** Tap any saved route drawn on the home map.

**Presentation:** Floating modal, centered on screen. Transparent backdrop (map still visible behind). Fades in — no slide animation.

**Layout:**

```
┌─────────────────────────────┐
│ Route Name            [  X ]│
│ 12.4 km · ↑ 320 m · ↓ 210 m│
│                             │
│ [ Edit ]  [ Export ]        │
└─────────────────────────────┘
```

- Route name: top-left
- X close button: top-right, same vertical alignment as route name
- Stats: one line below name — distance · ↑ gain · ↓ loss
- Edit button: bottom-left, square icon button, text "Edit"
- Export button: right of Edit, text "Export"
- No color indicator. No delete.

**Export behavior:** Triggers the Android system share intent with the `.gpx` file attached. The system sheet allows the user to save to Downloads, share to another app, etc.

---

## 3. Route List Sheet

**Behavior:** Peeks at the bottom of the home map at all times. Draggable up to fully open. No intermediate snap point.

**Layout (top → bottom):**

1. **Handle** — small grey line centered at top of sheet
2. **Route list** — scrollable, fills all available space between handle and the bottom buttons
3. **Bottom buttons** — fixed at the very bottom of the sheet:
   - When routes exist: **Import GPX** and **Export All** side by side (equal width)
   - When no routes: **Import GPX** only (full width)

**Route row:**
- Route name (left-aligned)
- Distance · ↑ gain (up arrow) · ↓ loss (down arrow) in appropriate units

Tapping a row opens that route directly in the editor.

**Empty state:** "Add a route" button replaces the list content.

**No delete action in this sheet.**

---

## 4. Route Editor Screen

### Top-left
Back button — left caret icon. Navigating back when unsaved changes exist triggers the Unsaved Changes Guard modal.

> Note: the back/save buttons also live inside the editor stats sheet (see Section 5). The top-left back button is a secondary shortcut.

### Top-right vertical stack (top → bottom)

| Icon | Action | Notes |
|---|---|---|
| Layers | Open layer popover | Same as home map |
| GPS / locate | Center camera on location | Same as home map |
| Undo | Undo last action | — |
| Redo | Redo (flipped undo icon) | — |
| Magnet | Toggle snap-to-trail | Per-segment; see Snap behavior below |
| Trash | Delete selected waypoint | Disabled if no waypoint selected or only 1 waypoint exists |

### Map state
All previously saved routes are hidden while the editor is open.

### Waypoint visuals

| Element | Fill | Border | Size | Label |
|---|---|---|---|---|
| Start waypoint | Green | Route color | 8 px diameter | None |
| End waypoint | Red | Route color | 8 px diameter | None |
| Middle waypoints | White | Route color | 6 px diameter | Number (1, 2, 3…) |
| Midpoint insert button | Route color | Route color | 6 px diameter | None — blends into route line as a solid dot |
| Selected waypoint | — | — | — | Yellow glow / halo |

**Route line:** Solid, 3 px width, route color.

**Drag state:** While dragging a waypoint, the segments connecting it to its neighbors are replaced by dashed straight lines. Once drag ends:
- Snapped segment: line stays dashed until snap routing resolves, then becomes the snapped solid line.
- Unsnapped segment: line immediately becomes a solid straight line.

### Snap-to-trail behavior
The magnet toggle controls whether the segment *after* the next dropped waypoint will snap to trails. Each segment is independently snapped or straight. The current toggle state is shown on the icon (on/off).

### Waypoint interactions
- **Long-press on map** → drops a new waypoint at that location (connected to previous end)
- **Tap a waypoint** → selects it (activates trash button in top-right stack; shows yellow glow)
- **Drag a waypoint** → repositions it; segment(s) re-route on release
- **Tap a midpoint insert button** → inserts a new waypoint between the two neighboring waypoints
- **Undo / Redo** → steps through waypoint add/move/delete history within the current session (not persisted)

---

## 5. Editor Stats Sheet

**Snap positions:**
1. Closed — handle only peeking at the bottom
2. First open — shows header row + elevation chart
3. Full open — 66% of screen height; shows all content

**Layout (top → bottom):**

```
────────── handle ──────────
[ ← ] [ Route name input  ] [ 💾 ]
┌─────────────────────────────┐
│  Elevation profile chart    │
└─────────────────────────────┘
○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○  (color swatches)
[ Pace input ] [ Est. time   ]
[ Save (green) ] [ Delete (red) ]
```

**Header row:** Left caret back button · route name text input (fills remaining width) · save icon button. All three are the same height, square icon buttons for the action buttons.

**Elevation profile chart:**
- Stats row: distance · ↑ gain · ↓ loss. When scrubbing, elevation at that point + distance from start appears on the right of the stats row.
- SVG chart below stats row: gradient fill under the elevation curve, elevation polyline, x-axis distance ticks (start / midpoint / end), y-axis min and max elevation labels.
- Touch/drag interaction: tap a point → vertical dashed line + filled dot on curve at that position; tapping also flies the map camera to the corresponding map coordinate. Dragging moves the marker without flying the camera.

**Color swatches:** Horizontal row of circles. Colors: white, black, gray, then light and dark versions of red, orange, yellow, green, blue, indigo, violet. Tap a swatch to set the route color.

**Pace row:** Pace input field on the left; calculated estimated time for the route displayed on the right.

**Action row:** [Save] and [Delete] side by side, full width.
- Save: solid green button
- Delete: solid red button → triggers Delete Confirmation modal

**Back button behavior:** Same as top-left back button — prompts Unsaved Changes Guard if changes exist.

---

## 6. Map Layer Switcher Popover

- Trigger: Layers icon (top-right of home map or editor)
- Position: Appears to the left of the icon, top-aligned with it
- Content: vertical list of rows — Satellite, Topo, Trail overlay, Street/Road
- Active layer: row has a darker background
- Dismiss: tap anywhere outside the popover, or select a different (non-active) layer

---

## 7. Search Modal

- Trigger: Search icon (top-right stack)
- Presentation: fades in (no slide). Full screen width and height with small padding on all sides. Transparent overlay — map is visible behind the padding area.

**Layout:**
- Top-right of modal: X button to close and dismiss
- Below X: text input field with an inline X button on the right side to clear the input text
- Auto-searches after 2 or more characters are entered
- Results list below the input: each row shows place name + location (city, state/region, country)
- Empty / no results state: "No results found" text

**On result tap:** Modal dismisses; map camera pans to the selected location. No waypoint is created.

---

## 8. Settings Screen

**Navigation:** Full-screen push from gear icon. "< back" text button in the top-left returns to the home map.

### Units
- Toggle slider: km ↔ miles
- **Distance display rule:** show in meters or feet when below 1 km or 1 mile; switch to km or miles with 2 decimal places (e.g. 1.25 km) at or above the threshold
- **Elevation display:** always in meters (metric) or feet (imperial) — never switches to km/miles

### Default Map Layer
Select / dropdown box. Same layer options as the layer switcher popover.

### Sync error handling

When the app cannot reach Supabase (network offline, server unreachable), sync fails gracefully:
- Errors are never surfaced as crashes or raw exception text.
- A red "Can't sync at this time" SnackBar appears in place of the "Sync complete" message.
- Applies both to the manual "Sync now" action and the automatic sync triggered after sign-in.

### Account

**Signed out:**
- "Sign in" button → opens Sign In Sheet (bottom sheet)

**Sign In Sheet layout (top → bottom):**
- Email field
- Password field
- "Forgot password" link → replaces the form with: email field + submit button
- "Register" link → replaces the form with: email field, password field, confirm password field, submit button → on submit shows confirmation message + "Back to sign in" button

**Signed in:**
- Email address displayed
- Sync status
- "Sign out" button below

### Downloaded Regions
- "Downloaded Regions" button → returns user to the map with the Downloaded Regions Sheet open

---

## 9. Downloaded Regions Sheet

**Presentation:** Bottom sheet overlaid on the full-screen map (same map as home).

**Snap positions:** Peek (handle only) and 40% screen height.

**Sheet layout (top → bottom):**
1. Handle
2. Back button (top-left of sheet, not top of screen) — returns to Settings
3. "+ Download region" button
4. List of downloaded regions

**Region row:** Region name · file size · [View] [Delete]
- **View:** closes sheet momentarily; map zooms to show the bounding box outline of that region
- **Delete:** shows Delete Region confirmation modal — "Are you sure you want to delete this region?" + [Cancel] [Delete]

**Empty state:** Only the "+ Download region" button is shown.

---

## 10. Offline Region Download (Bbox Selection)

**Trigger:** "+ Download region" button in the Downloaded Regions sheet.

**Presentation:** Full-screen map view (replaces current screen).

**Top-left:** "< back" button. If the user has moved or resized the box, or entered a name, triggers the Leave Confirmation modal before navigating away.

**Top-right:** Layers icon · GPS/center-on-me icon (same behavior as home map).

**Map overlay:**
- A transparent rectangle is pre-drawn with a solid color border when the screen opens.
- Each corner of the rectangle has a draggable dot.
- **To resize:** long-press a corner dot to activate drag mode; drag to resize. The rectangle stays fixed in screen space — it does not change size when the user pans or zooms the map.
- Pinch-to-zoom is disabled while a corner dot is being dragged.
- The estimated download size label updates in real time as the box is resized.

**Persistent bottom bar (fixed, not a sheet):**

```
Estimated download size: 42 MB
[ Region name input field .............. ] [ Save ]
```

- "Estimated download size: [size]" label
- Name input field (below the size label)
- Save button to the right of the name input, on the same row

---

## 11. GPX Import

**Entry point:** Import button fixed at the bottom of the Route List Sheet on the home map.

**Flow:**
1. Tapping Import → OS file picker opens (primary path). If the user shares a `.gpx` file from another app (e.g. Gaia GPS) into this app, it routes to the same import flow.
2. User selects a `.gpx` file.
3. "Importing" modal appears — spinning icon centered above the text "Importing".
4. On success: route loads into the editor fully editable, identical to a manually created route. User must explicitly save.

---

## 12. GPX Export

**Entry point:** Export button in the Route Detail Modal (single route), or "Export All" button in the Route List Sheet (all routes).

**Single-route flow:** Triggers the Android system share intent with the `.gpx` file. The system sheet gives the user native options: save to Downloads, share via messaging, open in another app, etc.

**Export All flow:** Generates a single GPX 1.1 file containing one `<trk>` element per saved route. Triggers the Android share intent with that file. Routes with no geometry (no waypoints ever routed) are omitted. The "Export All" button is only shown when at least one route exists.

---

## 13. Delete Route

**Entry point:** Red "Delete" button in the Editor Stats Sheet action row.

**Confirmation modal:**
> "Are you sure you want to delete this route?"
> [Cancel] [Delete]

Delete is not available from the Route List Sheet or Route Detail Modal.

---

## 14. Unsaved Changes Guard

**Triggers:** Back button (top-left or in sheet header) in the Route Editor when unsaved changes exist.

**Modal:**
> "Are you sure you want to leave? All information will be lost."
> [Cancel] [Leave]

---

## 15. Unit & Display Rules (Summary)

| Measurement | Below threshold | At / above threshold |
|---|---|---|
| Distance (metric) | meters (e.g. 850 m) | km to 2 dp (e.g. 1.25 km) |
| Distance (imperial) | feet (e.g. 2,800 ft) | miles to 2 dp (e.g. 1.25 mi) |
| Elevation | always meters or feet — no km/mi conversion |

---

## 16. Interaction Reference

| Gesture | Where | Result |
|---|---|---|
| Long-press on map | Editor map | Drops new waypoint |
| Tap waypoint | Editor map | Selects it (yellow glow; enables trash) |
| Drag waypoint | Editor map | Repositions waypoint; re-routes on release |
| Tap midpoint dot | Editor map | Inserts waypoint between neighbors |
| Long-press corner dot | Bbox screen | Activates corner drag/resize mode |
| Tap route on map | Home map | Opens Route Detail Modal |
| Tap result in search | Search modal | Dismisses modal; pans map to location |
| Drag sheet up/down | Any sheet | Opens / collapses to snap points |
| Tap outside popover | Layer switcher | Dismisses popover |
| Tap outside modal | Search modal | Does not dismiss (use X button) |
| Touch/drag elevation chart | Editor stats sheet | Scrubs position; tap flies camera |
