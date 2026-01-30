# Save Path Inference Strategy Analysis

## Problem Statement

When syncing saves between devices, we face a challenge: **if a save only exists on Device A, how do we determine where to place it on Device B?**

Currently, the manifest endpoint only returns saves that have a `SaveLocation` entry for the requesting device. This means:
- Device A uploads a save → Creates `SaveLocation` for Device A
- Device B requests manifest → No `SaveLocation` for Device B → Save doesn't appear
- Device B can't download the save, even though it exists in the cloud

## Current System Architecture

1. **Save Discovery**: Client scans known save directories (e.g., `/mnt/SDCARD/Saves/saves`, `/MUOS/save/file`)
2. **Upload**: When a save is uploaded, a `SaveLocation` is created with the device's `localPath`
3. **Manifest**: Only returns saves where `deviceId` matches the requesting device
4. **Download**: Client uses `localPath` from manifest to determine where to save files

## Path Structure Patterns

Based on the codebase, save paths typically follow these patterns:

### SpruceOS/Onion-style:
```
/mnt/SDCARD/Saves/saves/[core]/[game]/[savefile.sav]
```

### muOS:
```
/SD1 (mmc)/MUOS/save/file/[core]/[game]/[savefile.sav]
/MUOS/save/file/[core]/[game]/[savefile.sav]
/mnt/mmc/MUOS/save/file/[core]/[game]/[savefile.sav]
/mnt/sdcard/MUOS/save/file/[core]/[game]/[savefile.sav]
```

The **core** and **game** segments are typically preserved across devices, but the **base path** differs.

## Option A: Path Inference Based on Device Context

### Approach
When Device B requests a manifest for a save that only exists on Device A:
1. Extract the relative path components (core/game/filename) from Device A's path
2. Look at Device B's existing `SaveLocation` entries to infer the base path pattern
3. If Device B has other saves from the same core/game, use that pattern
4. If not, try to infer based on `deviceType` and known path mappings

### Pros
- ✅ Works immediately - no user action required
- ✅ Enables automatic syncing for new devices
- ✅ Better user experience (seamless sync)

### Cons
- ❌ Complex logic with edge cases
- ❌ Risk of incorrect path inference (wrong location = lost saves)
- ❌ Different OS distributions may have different structures
- ❌ Multiple cores for same game complicate inference
- ❌ What if Device B has no saves yet? (chicken-and-egg problem)

### Implementation Complexity
**High** - Requires:
- Path parsing and component extraction
- Device-specific path mapping rules
- Fallback strategies when inference fails
- Validation to ensure inferred paths are valid

## Option B: Require Initial Save Upload

### Approach
Require that users run a game at least once on Device B before syncing can begin:
1. Device B must upload at least one save file first
2. This creates `SaveLocation` entries for Device B
3. System can then infer paths for other saves based on existing patterns
4. Show clear UI message: "Run a game once to enable syncing"

### Pros
- ✅ Simple and reliable - uses actual device paths
- ✅ No risk of incorrect path inference
- ✅ Works with any OS/distribution structure
- ✅ Handles edge cases naturally (user's actual paths)

### Cons
- ❌ Requires user action before syncing works
- ❌ Slightly worse UX (extra step)
- ❌ What if user wants to sync before playing?

### Implementation Complexity
**Low** - Requires:
- UI messaging to guide users
- Optional: Auto-detect when first save appears and prompt user

## Recommended Hybrid Approach

Combine both strategies for the best user experience:

### Phase 1: Attempt Inference (Best Effort)
1. When Device B requests manifest, include saves that don't have a `SaveLocation` for Device B
2. For each such save:
   - Extract relative path components (core/game/filename) from other devices' paths
   - Look at Device B's existing `SaveLocation` entries
   - If Device B has saves from the same core, infer path using same base pattern
   - If Device B has saves from different cores but same base path structure, use that
   - If no inference possible, mark as "needs mapping"

### Phase 2: Fallback to User Action
3. For saves that can't be inferred:
   - Include in manifest with a special flag: `inferredPath: null` or `needsMapping: true`
   - Client can show: "New save available: [game name]. Run the game once to enable syncing."
   - Once Device B uploads any save, create `SaveLocation` and retry inference

### Phase 3: Path Mapping Rules (Device Type Based)
4. Create a mapping table for common device types:
   ```typescript
   const PATH_MAPPINGS = {
     'rg35xx': {
       basePaths: ['/mnt/SDCARD/Saves/saves'],
       pattern: '{basePath}/{core}/{game}/{filename}'
     },
     'miyoo_flip': {
       basePaths: ['/mnt/SDCARD/Saves/saves'],
       pattern: '{basePath}/{core}/{game}/{filename}'
     },
     // muOS devices might need special handling
   }
   ```

### Implementation Strategy

1. **Modify Manifest Endpoint** (`/api/sync/manifest/route.ts`):
   - Include saves that don't have `SaveLocation` for requesting device
   - Add inference logic to suggest paths
   - Mark saves with `inferredPath: string | null`

2. **Client-Side Handling**:
   - If `inferredPath` exists, use it (with validation)
   - If `inferredPath` is null, show message to user
   - When user uploads first save, trigger re-sync

3. **Path Inference Algorithm**:
   ```typescript
   function inferPath(
     sourcePath: string,
     targetDevice: Device,
     existingLocations: SaveLocation[]
   ): string | null {
     // 1. Extract components: basePath, core, game, filename
     // 2. Find existing locations on target device with same core
     // 3. If found, use same basePath pattern
     // 4. Else, try deviceType-based mapping
     // 5. Else, return null (needs user action)
   }
   ```

## Recommendation

**Start with Option B (require initial upload)**, then add **Option A (inference)** as an enhancement:

### Why?
1. **Reliability First**: Path inference is risky - wrong paths = lost saves
2. **Progressive Enhancement**: Get basic syncing working reliably first
3. **User Control**: Users understand their own file structure better
4. **Simpler Implementation**: Less code = fewer bugs

### Migration Path
1. **Phase 1** (Now): Implement Option B with clear messaging
2. **Phase 2** (Later): Add smart inference for common cases
3. **Phase 3** (Future): Learn from user patterns to improve inference

## Example User Flow (Option B)

1. User pairs Device B
2. Dashboard shows: "No saves found. Run a game once to enable syncing."
3. User plays a game on Device B → Save is uploaded
4. System now knows Device B's path structure
5. Next sync: System can infer paths for other saves from Device A
6. Downloads proceed automatically

## Example User Flow (Hybrid)

1. User pairs Device B
2. System attempts to infer paths from Device A's saves
3. For saves where inference succeeds: Download automatically
4. For saves where inference fails: Show "Run [game] once to enable syncing"
5. User plays game → Save uploaded → Inference retries → Download succeeds

## Questions to Consider

1. **How common is the "no saves yet" scenario?** If rare, inference is less critical
2. **How similar are path structures across devices?** If very similar, inference is safer
3. **What's the cost of wrong inference?** Lost saves vs. delayed sync
4. **Can we validate inferred paths?** Check if directory exists before downloading?

## Conclusion

**Recommended: Start with Option B, enhance with Option A later.**

This gives us:
- ✅ Reliable syncing from day one
- ✅ Clear user guidance
- ✅ Foundation for smart inference later
- ✅ Lower risk of data loss
