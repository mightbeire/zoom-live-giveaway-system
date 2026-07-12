window.ZOOM_GIVEAWAY_CONFIG = {
  // Use the base of the n8n Cloud workspace, without a trailing slash.
  // Example: "https://your-workspace.app.n8n.cloud"
  n8nBaseUrl: "https://YOUR-N8N-WORKSPACE",

  // This must match the header name configured in both Workflow 3 webhooks.
  authHeaderName: "x-admin-key",

  // Optional defaults. The operator can still edit them on the page.
  defaultMeetingId: "",
  defaultMeetingUuid: "",

  // Status refresh interval after connecting.
  refreshMs: 5000
};
