let token = null;
const api = async (path, options = {}) => {
  const response = await fetch(`/api/v1${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, ...(options.headers || {}) },
  });
  if (!response.ok) throw new Error((await response.json()).detail || "Request failed");
  return response.status === 204 ? null : response.json();
};
const message = (text = "") => { document.querySelector("#message").textContent = text; };
const escapeHtml = value => String(value).replace(/[&<>'"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]);

document.querySelector("#login-form").addEventListener("submit", async event => {
  event.preventDefault(); message();
  try {
    const result = await fetch("/api/v1/auth/login", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: email.value, password: password.value }) });
    if (!result.ok) throw new Error("Sign in failed");
    token = (await result.json()).access_token; // intentionally memory-only
    document.querySelector("#login-panel").hidden = true;
    document.querySelector("#dashboard").hidden = false;
    await refresh();
  } catch (error) { message(error.message); }
});
document.querySelector("#sign-out").onclick = () => { token = null; location.reload(); };

async function refresh() {
  try {
    const [cases, alerts] = await Promise.all([api("/officer/cases"), api("/officer/pattern-alerts")]);
    document.querySelector("#case-list").innerHTML = cases.map(item => `<button class="case" data-id="${item.id}"><strong>${item.status.replaceAll("_", " ")}</strong><br><span class="meta">${item.created_at.slice(0, 10)}</span></button>`).join("") || "No cases in queue.";
    document.querySelector("#alert-list").innerHTML = alerts.map(item => `<p class="alert"><strong>Review required</strong><br>${item.report_count} independent reports in 90 days</p>`).join("") || "No active pattern-review alerts.";
    document.querySelectorAll(".case").forEach(button => button.onclick = () => openCase(button.dataset.id));
  } catch (error) { message(error.message); }
}
async function openCase(id) {
  try {
    const item = await api(`/officer/cases/${id}`);
    const events = item.timeline.map(event => `<div class="event"><strong>${escapeHtml(new Date(event.occurred_at).toLocaleString())}</strong><br>${escapeHtml(event.narrative)}</div>`).join("");
    document.querySelector("#case-detail").innerHTML = `<p><strong>Status:</strong> ${item.status.replaceAll("_", " ")}</p><label>Update status <select id="case-status">${["received", "under_review", "action_required", "closed"].map(status => `<option ${status === item.status ? "selected" : ""}>${status}</option>`).join("")}</select></label><button id="update-status">Save status</button><h4>Incident timeline</h4>${events}`;
    document.querySelector("#update-status").onclick = async () => { await api(`/officer/cases/${id}/status`, { method: "PATCH", body: JSON.stringify({ status: document.querySelector("#case-status").value }) }); await refresh(); message("Status updated. The student receives a generic confidential notification."); };
  } catch (error) { message(error.message); }
}
