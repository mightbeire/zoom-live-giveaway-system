(() => {
  "use strict";
  const config = window.ZOOM_GIVEAWAY_CONFIG;
  const $ = (id) => document.getElementById(id);
  let poll = null;
  let latest = null;
  let lockedResult = null;

  $("meetingId").value = config.defaultMeetingId || "";
  $("meetingUuid").value = config.defaultMeetingUuid || "";
  $("adminKey").value = sessionStorage.getItem("zoomGiveawayAdminKey") || "";

  function values() {
    return {
      meetingId: $("meetingId").value.trim(),
      meetingUuid: $("meetingUuid").value.trim(),
      key: $("adminKey").value
    };
  }

  function authHeaders(json = false) {
    const h = { [config.authHeaderName]: values().key };
    if (json) h["Content-Type"] = "application/json";
    return h;
  }

  async function call(url, options = {}) {
    const response = await fetch(url, options);
    const text = await response.text();
    let data;
    try { data = text ? JSON.parse(text) : {}; }
    catch { data = { raw: text }; }
    if (!response.ok || data.ok === false) throw new Error(data.error || `Request failed (${response.status})`);
    return data;
  }

  function number(id, value) {
    $(id).textContent = Number.isFinite(Number(value)) ? Number(value).toLocaleString() : "—";
  }

  function connection(text, online) {
    $("connection").textContent = text;
    $("connection").classList.toggle("online", online);
  }

  function showStatus(data) {
    latest = data;
    connection("Connected", true);
    number("registered", data.registered);
    number("connectedSessions", data.connectedSessions);
    number("identifiedEntrants", data.identifiedEntrants);
    number("staffConnected", data.staffConnected);
    number("unmatchedParticipants", data.unmatchedParticipants);
    number("currentlyEligible", data.currentlyEligible);
    $("stateTitle").textContent = data.locked ? "Entries are locked" : "Attendance is still live";
    $("stateBadge").textContent = data.locked ? "LOCKED" : "OPEN";
    $("updated").textContent = `Updated ${new Date().toLocaleTimeString()}`;
    $("lockBtn").disabled = data.locked || Number(data.currentlyEligible) < 1;
    if (data.locked && data.sheetUrl) {
      showLocked({
        eligibleCount: data.eligibleCount,
        rng: { min: 1, max: data.eligibleCount },
        instruction: `Use random-number range 1 to ${data.eligibleCount}.`,
        sheetUrl: data.sheetUrl
      });
    }
  }

  async function refresh() {
    const v = values();
    if (!v.meetingId || !v.key) throw new Error("Meeting ID and admin key are required.");
    connection("Refreshing…", false);
    const query = new URLSearchParams({ meetingId: v.meetingId, meetingUuid: v.meetingUuid });
    const data = await call(`${config.n8nBaseUrl}/webhook/zoom-giveaway/status?${query}`, { headers: authHeaders(false) });
    showStatus(data);
  }

  function showLocked(data) {
    lockedResult = data;
    $("emptyResult").hidden = true;
    $("lockedResult").hidden = false;
    $("rngMin").textContent = data.rng?.min ?? 1;
    $("rngMax").textContent = data.rng?.max ?? data.eligibleCount;
    $("instruction").textContent = data.instruction || "";
    $("sheetLink").href = data.sheetUrl;
  }

  async function lock() {
    const v = values();
    if (!v.meetingId || !v.meetingUuid || !v.key) throw new Error("Meeting ID, meeting UUID and admin key are required.");
    $("lockBtn").disabled = true;
    $("lockBtn").textContent = "Locking…";
    try {
      const data = await call(`${config.n8nBaseUrl}/webhook/zoom-giveaway/lock`, {
        method: "POST",
        headers: authHeaders(true),
        body: JSON.stringify({ meetingId: v.meetingId, meetingUuid: v.meetingUuid, requestedBy: "creator-dashboard" })
      });
      showLocked(data);
      await refresh();
    } finally {
      $("lockBtn").textContent = "Lock giveaway list";
      if (!latest?.locked) $("lockBtn").disabled = false;
    }
  }

  function report(error) {
    connection("Connection failed", false);
    alert(error.message || String(error));
  }

  $("connectBtn").addEventListener("click", () => {
    sessionStorage.setItem("zoomGiveawayAdminKey", values().key);
    clearInterval(poll);
    refresh().catch(report);
    poll = setInterval(() => refresh().catch(() => connection("Refresh failed", false)), config.refreshMs || 5000);
  });
  $("refreshBtn").addEventListener("click", () => refresh().catch(report));
  $("lockBtn").addEventListener("click", () => $("confirmDialog").showModal());
  $("confirmDialog").addEventListener("close", () => {
    if ($("confirmDialog").returnValue === "confirm") lock().catch(report);
  });
  $("copyBtn").addEventListener("click", async () => {
    const min = lockedResult?.rng?.min ?? 1;
    const max = lockedResult?.rng?.max ?? lockedResult?.eligibleCount;
    await navigator.clipboard.writeText(`${min}-${max}`);
    $("copyBtn").textContent = "Copied";
    setTimeout(() => $("copyBtn").textContent = "Copy range", 1200);
  });
})();
