-- src/state.lua
-- Single source of truth for all mutable app/UI/sync state.
-- Other modules require "src.state" and read/write state.*.
-- Depends: src.config (for initial state enum values).

local config = require("src.config")

local state = {
    -- App / pairing
    currentState = config.STATE_SHOWING_CODE,
    apiKey = nil,
    deviceName = nil,
    deviceCode = nil,
    pairingError = "",
    isPaired = false,
    serverUrl = config.SERVER_URL,

    -- Upload
    uploadProgress = "",
    uploadSuccess = 0,
    uploadTotal = 0,
    uploadCancelled = false,
    uploadPending = false,
    uploadJustStarted = false,
    uploadDiscoverPending = false,
    weStartedWatcher = false,
    uploadInProgress = false,
    uploadQueue = {},
    uploadNextIndex = 1,
    uploadFailedFiles = {},

    -- Download
    downloadProgress = "",
    downloadSuccess = 0,
    downloadTotal = 0,
    downloadCancelled = false,
    downloadPending = false,
    downloadInProgress = false,
    downloadQueue = {},
    downloadNextIndex = 1,
    downloadFailedFiles = {},
    unmappedSavesCount = 0,

    -- Per-sync-session summary
    syncSessionHadUpload = false,
    syncSessionHadDownload = false,

    -- Files list (Recent)
    savesList = {},
    filesListScroll = 0,
    filesListSelectedIndex = 1,
    filesListLoading = false,
    filesListError = "",
    filesListPending = false,

    -- Home menu (CONNECTED)
    homeSelectedIndex = 1,

    -- Settings
    settingsSelectedIndex = 1,
    settingsStatusMessage = "",
    musicEnabled = false,
    soundsEnabled = false,
    themeId = "classic",

    -- Device history (data only; no UI screen)
    deviceHistory = {},

    -- Confirm screen (generic: unpair, etc.)
    confirmMessage = "",
    confirmYesLabel = "Yes",
    confirmNoLabel = "No",
    confirmAction = "",       -- e.g. "unpair"
    confirmSelectedIndex = 1, -- 1 = Yes, 2 = No
    confirmBackState = nil,   -- state enum to return to on No/Cancel

    -- Loading overlay (background toggle, etc.)
    loadingMessage = "Loading...",
    loadingBackState = nil,
    loadingDoneChannel = nil, -- love.thread channel to poll for completion

    -- Scan paths: single list from scan_paths.json (default + custom). Synced to server.
    scanPathEntries = {},
    pathAddedMessage = nil,
    pathAddedAt = nil,
    dragOverWindow = false,  -- true while cursor held from outside is over window (isdropping)
    scanPathsLastSentAt = 0,
    scanPathsDirty = true,
    noPathsMessageDismissed = false,  -- one-time "no paths" overlay dismissed (A or click)

    -- Intro / timers
    homeIntroTimer = 0,
    codeIntroTimer = 0,
    lastInputTime = 0,
    pollTimer = 0,
    codeDisplayTimer = 0,
    pollIndicator = 0,
    uploadStartTimer = 0,
    pollCount = 0,

    -- Assets (set by main or assets module)
    titleFont = nil,
    codeFont = nil,
    largeCountFont = nil,
    deviceFont = nil,
    bgMusic = nil,
    uiHoverSound = nil,
    uiSelectSound = nil,
    uiBackSound = nil,
    uiStartSyncSound = nil,
}

return state
