// Shared JS — sidebar, auth guard, API config
const API_BASE = window.API_BASE || 'https://dpbq0p1cb7.execute-api.ap-south-1.amazonaws.com/prod';
const COGNITO_DOMAIN = window.COGNITO_DOMAIN || 'https://sqp-prod-103536d6.auth.ap-south-1.amazoncognito.com';

function getUser() {
  try { return JSON.parse(sessionStorage.getItem('user')); } catch { return null; }
}

function requireAuth(allowedRoles) {
  const user = getUser();
  if (!user) { window.location.href = 'index.html'; return null; }
  if (allowedRoles && !allowedRoles.includes(user.role)) {
    window.location.href = user.role === 'supplier' ? 'supplier-portal.html' : 'dashboard.html';
    return null;
  }
  return user;
}

function logout() {
  sessionStorage.clear();
  window.location.href = 'index.html';
}

function renderSidebar(activePage) {
  const user = getUser();
  const isSupplier = user?.role === 'supplier';
  const adminLinks = isSupplier ? '' : `
    <a class="nav-item ${activePage==='dashboard'?'active':''}" href="dashboard.html">
      <span class="nav-icon">📊</span> Dashboard
    </a>
    <a class="nav-item ${activePage==='audits'?'active':''}" href="audit-list.html">
      <span class="nav-icon">📋</span> Audit Management
      <span class="nav-badge" id="pending-badge">0</span>
    </a>
    <a class="nav-item ${activePage==='compliance'?'active':''}" href="compliance.html">
      <span class="nav-icon">🛡️</span> Compliance Certs
    </a>
    <a class="nav-item ${activePage==='reports'?'active':''}" href="reports.html">
      <span class="nav-icon">📈</span> Reports & Analytics
    </a>
  `;
  return `
    <div class="sidebar">
      <div class="sidebar-logo">
        <div class="sidebar-logo-icon">🏭</div>
        <div class="sidebar-logo-text">
          <h2>SupplierQ Portal</h2>
          <p>Quality & Compliance</p>
        </div>
      </div>
      <nav class="sidebar-nav">
        <div class="nav-section-label">Navigation</div>
        ${adminLinks}
        <a class="nav-item ${activePage==='supplier-portal'?'active':''}" href="supplier-portal.html">
          <span class="nav-icon">🏢</span> Supplier Portal
        </a>
        <div class="nav-section-label" style="margin-top:8px">System</div>
        <a class="nav-item" href="#" onclick="showSettings()">
          <span class="nav-icon">⚙️</span> Settings
        </a>
        <a class="nav-item" href="#" onclick="showHelp()">
          <span class="nav-icon">❓</span> Help & Docs
        </a>
      </nav>
      <div class="sidebar-footer">
        <div class="user-info">
          <div class="user-avatar">${(user?.name||'U')[0].toUpperCase()}</div>
          <div>
            <div class="user-name">${user?.name||'User'}</div>
            <div class="user-role">${formatRole(user?.role)}</div>
          </div>
          <button class="logout-btn" onclick="logout()" title="Sign Out">⏻</button>
        </div>
      </div>
    </div>`;
}

function formatRole(role) {
  const map = { admin: 'Administrator', quality_manager: 'Quality Manager', supplier: 'Supplier User' };
  return map[role] || role || 'User';
}

function renderHeader(title, subtitle) {
  return `
    <header class="header">
      <div class="header-title">
        <h1>${title}</h1>
        ${subtitle ? `<p>${subtitle}</p>` : ''}
      </div>
      <div class="header-actions">
        <button class="header-btn" onclick="toggleNotifications()" data-tooltip="Notifications">
          🔔 <span class="badge" id="notif-count">5</span>
        </button>
        <button class="header-btn" data-tooltip="Search (Ctrl+K)" onclick="focusSearch()">🔍</button>
        <button class="header-btn" data-tooltip="AWS Console" onclick="window.open('https://console.aws.amazon.com','_blank')">☁️</button>
      </div>
    </header>`;
}

async function apiFetch(path, options = {}) {
  const user = getUser();
  const headers = {
    'Content-Type': 'application/json',
    ...(user?.token ? { 'Authorization': user.token } : {}),
    ...options.headers
  };
  try {
    const res = await fetch(API_BASE + path, { ...options, headers });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    console.warn('API error, using demo data:', err.message);
    return null;
  }
}

function formatDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function daysUntil(dateStr) {
  const diff = new Date(dateStr) - new Date();
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

function statusBadge(status) {
  const map = {
    'Completed': 'badge-green', 'Active': 'badge-green', 'Low': 'badge-green',
    'In Review': 'badge-blue', 'Pending': 'badge-amber',
    'Watch': 'badge-amber', 'Medium': 'badge-amber', 'Warning': 'badge-amber',
    'Failed': 'badge-red', 'Critical': 'badge-red', 'High': 'badge-red', 'Expired': 'badge-red',
    'Rejected': 'badge-red', 'Draft': 'badge-gray', 'Cancelled': 'badge-gray'
  };
  return `<span class="badge ${map[status]||'badge-gray'}">${status}</span>`;
}

function scoreColor(score) {
  if (score >= 85) return 'high';
  if (score >= 70) return 'medium';
  return 'low';
}

function scoreBar(score) {
  return `<div class="score-bar">
    <div class="score-track"><div class="score-fill ${scoreColor(score)}" style="width:${score}%"></div></div>
    <span class="score-value" style="color:${score>=85?'var(--accent-green)':score>=70?'var(--accent-amber)':'var(--accent-red)'}">${score}</span>
  </div>`;
}

function showNotification(msg, type = 'success') {
  const el = document.createElement('div');
  el.className = `alert alert-${type}`;
  el.style.cssText = 'position:fixed;top:80px;right:24px;z-index:9999;min-width:300px;animation:fadeIn 0.3s ease';
  el.innerHTML = `<span>${msg}</span>`;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3500);
}

function showSettings() { showNotification('⚙️ Settings panel coming soon!', 'info'); }
function showHelp() { window.open('https://docs.aws.amazon.com/', '_blank'); }
function toggleNotifications() { showNotification('🔔 You have 5 unread alerts. Check compliance section.', 'warning'); }
function focusSearch() { const s = document.querySelector('.search-bar input'); if (s) s.focus(); }
