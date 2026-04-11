// ── Config ──
const SUPABASE_URL = 'https://tcaaozzijpgbaqzpnahl.supabase.co';
const ANON_KEY = 'sb_publishable_Cm0aEtK1Uv9-F7GIiU_15A_AgGH2ALL';
const TABLE = 'suggestion_packs';

let accessToken = '';
let refreshToken = '';
let packs = [];
let editingPack = null; // null = new, object = editing existing
let dirty = false; // unsaved changes tracker

// ── API ──

function headers() {
  return {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };
}

async function fetchPacks() {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${TABLE}?select=*&order=sort_order.asc`,
    { headers: headers() }
  );
  if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
  return res.json();
}

async function upsertPack(pack) {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${TABLE}?on_conflict=id`,
    {
      method: 'POST',
      headers: { ...headers(), 'Prefer': 'return=representation,resolution=merge-duplicates' },
      body: JSON.stringify(pack),
    }
  );
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Save failed: ${res.status} ${body}`);
  }
  return res.json();
}

async function deletePack(id) {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${TABLE}?id=eq.${encodeURIComponent(id)}`,
    { method: 'DELETE', headers: headers() }
  );
  if (!res.ok) throw new Error(`Delete failed: ${res.status}`);
}

// ── Cover Image Upload ──

const COVERS_BUCKET = 'pack-covers';

async function uploadCoverImage(file) {
  const ext = file.name.split('.').pop().toLowerCase();
  const filename = `${Date.now()}.${ext}`;
  const res = await fetch(
    `${SUPABASE_URL}/storage/v1/object/${COVERS_BUCKET}/${filename}`,
    {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': file.type,
      },
      body: file,
    }
  );
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Upload failed: ${err}`);
  }
  return `${SUPABASE_URL}/storage/v1/object/public/${COVERS_BUCKET}/${filename}`;
}

function updateCoverPreview(url) {
  if (url) {
    coverPreviewImg.src = url;
    coverPreviewWrapper.classList.remove('hidden');
  } else {
    coverPreviewWrapper.classList.add('hidden');
    coverPreviewImg.src = '';
  }
}

// ── Dirty tracking ──

function markDirty() { dirty = true; }

function clearDirty() { dirty = false; }

window.addEventListener('beforeunload', (e) => {
  if (dirty) {
    e.preventDefault();
    e.returnValue = '';
  }
});

// ── Auth ──

const loginScreen = document.getElementById('login-screen');
const appScreen = document.getElementById('app-screen');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const loginBtn = document.getElementById('login-btn');
const loginError = document.getElementById('login-error');
const logoutBtn = document.getElementById('logout-btn');
const userEmail = document.getElementById('user-email');

loginBtn.addEventListener('click', handleLogin);
passwordInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') handleLogin(); });
emailInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') passwordInput.focus(); });

logoutBtn.addEventListener('click', async () => {
  try {
    await fetch(`${SUPABASE_URL}/auth/v1/logout`, {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Authorization': `Bearer ${accessToken}` },
    });
  } catch (_) {}
  accessToken = '';
  refreshToken = '';
  sessionStorage.removeItem('memorezar_access');
  sessionStorage.removeItem('memorezar_refresh');
  loginScreen.classList.remove('hidden');
  appScreen.classList.add('hidden');
});

async function handleLogin() {
  const email = emailInput.value.trim();
  const password = passwordInput.value;
  if (!email || !password) return;

  loginBtn.textContent = 'Signing in…';
  loginBtn.disabled = true;
  loginError.classList.add('hidden');

  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error_description || body.msg || `Login failed (${res.status})`);
    }

    const data = await res.json();
    accessToken = data.access_token;
    refreshToken = data.refresh_token;
    sessionStorage.setItem('memorezar_access', accessToken);
    sessionStorage.setItem('memorezar_refresh', refreshToken);

    if (userEmail) userEmail.textContent = email;
    loginScreen.classList.add('hidden');
    appScreen.classList.remove('hidden');
    loadPacks();
  } catch (e) {
    loginError.textContent = e.message;
    loginError.classList.remove('hidden');
  } finally {
    loginBtn.textContent = 'Sign In';
    loginBtn.disabled = false;
  }
}

async function refreshSession() {
  if (!refreshToken) return false;
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });
    if (!res.ok) return false;
    const data = await res.json();
    accessToken = data.access_token;
    refreshToken = data.refresh_token;
    sessionStorage.setItem('memorezar_access', accessToken);
    sessionStorage.setItem('memorezar_refresh', refreshToken);
    return true;
  } catch (_) {
    return false;
  }
}

// Auto-login from session
(async () => {
  const savedAccess = sessionStorage.getItem('memorezar_access');
  const savedRefresh = sessionStorage.getItem('memorezar_refresh');
  if (savedAccess && savedRefresh) {
    accessToken = savedAccess;
    refreshToken = savedRefresh;
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}?select=id&limit=1`, {
        headers: headers(),
      });
      if (res.status === 401) {
        const refreshed = await refreshSession();
        if (!refreshed) return;
      } else if (!res.ok) {
        return;
      }
      loginScreen.classList.add('hidden');
      appScreen.classList.remove('hidden');
      loadPacks();
    } catch (_) {
      // stay on login screen
    }
  }
})();

// Also ensure RLS allows admin to delete any recording/flag.
// If your Supabase RLS is restrictive, you may need a service_role key or
// admin-specific policies. The current setup uses the logged-in user's token.

// ── Pack List ──

const packListView = document.getElementById('pack-list-view');
const packListEl = document.getElementById('pack-list');
const addPackBtn = document.getElementById('add-pack-btn');
const packEditor = document.getElementById('pack-editor');
const backBtn = document.getElementById('back-btn');
const packSearchInput = document.getElementById('pack-search');

addPackBtn.addEventListener('click', () => openEditor(null));
backBtn.addEventListener('click', () => {
  if (dirty) {
    if (!confirm('You have unsaved changes. Are you sure you want to go back?')) return;
  }
  clearDirty();
  closeEditor();
});

packSearchInput.addEventListener('input', renderPackList);

async function loadPacks() {
  packListEl.innerHTML = '<div class="loading">Loading packs…</div>';
  try {
    packs = await fetchPacks();
    renderPackList();
  } catch (e) {
    if (e.message.includes('401') || e.message.includes('403')) {
      const refreshed = await refreshSession();
      if (refreshed) {
        try {
          packs = await fetchPacks();
          renderPackList();
          return;
        } catch (_) {}
      }
    }
    packListEl.innerHTML = `<div class="empty-state"><p>Failed to load packs: ${e.message}</p></div>`;
  }
}

function renderPackList() {
  const query = packSearchInput.value.trim().toLowerCase();
  const filtered = query
    ? packs.filter(p =>
        p.name.toLowerCase().includes(query) ||
        p.id.toLowerCase().includes(query) ||
        (p.description || '').toLowerCase().includes(query)
      )
    : packs;

  if (filtered.length === 0) {
    packListEl.innerHTML = query
      ? '<div class="empty-state"><p>No packs match your search.</p></div>'
      : '<div class="empty-state"><p>No packs yet. Create your first one!</p></div>';
    return;
  }

  packListEl.innerHTML = filtered.map(p => `
    <div class="pack-card" data-id="${esc(p.id)}">
      <div class="pack-card-header">
        <h4>${esc(p.name)}</h4>
      </div>
      <p>${esc(p.description)}</p>
      <div class="pack-meta">
        <span>${p.quotes ? p.quotes.length : 0} quotes</span>
        <span>v${p.version || 1}</span>
        <span>order: ${p.sort_order ?? 0}</span>
        <span class="${p.is_free === false ? 'badge-pro' : 'badge-free'}">${p.is_free === false ? 'PRO' : 'FREE'}</span>
        <span>id: ${esc(p.id)}</span>
      </div>
    </div>
  `).join('');

  packListEl.querySelectorAll('.pack-card').forEach(card => {
    card.addEventListener('click', () => {
      const pack = packs.find(p => p.id === card.dataset.id);
      if (pack) openEditor(pack);
    });
  });
}

// ── Pack Editor ──

const editorTitle = document.getElementById('editor-title');
const packIdInput = document.getElementById('pack-id');
const packNameInput = document.getElementById('pack-name');
const packDescInput = document.getElementById('pack-description');
const packCoverUrlInput = document.getElementById('pack-cover-url');
const packCoverFileInput = document.getElementById('pack-cover-file');
const coverPreviewWrapper = document.getElementById('cover-preview-wrapper');
const coverPreviewImg = document.getElementById('cover-preview-img');
const packSortInput = document.getElementById('pack-sort-order');
const packVersionInput = document.getElementById('pack-version');
const packIsFreeInput = document.getElementById('pack-is-free');
const quoteCountBadge = document.getElementById('quote-count');
const quotesListEl = document.getElementById('quotes-list');
const addQuoteBtn = document.getElementById('add-quote-btn');
const savePackBtn = document.getElementById('save-pack-btn');
const deletePackBtn = document.getElementById('delete-pack-btn');
const toggleAllBtn = document.getElementById('toggle-all-quotes');
const addLangAllBtn = document.getElementById('add-lang-all-btn');

const packTransContainer = document.getElementById('pack-translations-container');
const addPackTransBtn = document.getElementById('add-pack-translation');

// Track dirty on editor inputs
document.querySelectorAll('#pack-editor input, #pack-editor textarea').forEach(el => {
  el.addEventListener('input', markDirty);
  el.addEventListener('change', markDirty);
});

packCoverFileInput.addEventListener('change', async () => {
  const file = packCoverFileInput.files[0];
  if (!file) return;
  try {
    packCoverFileInput.disabled = true;
    const url = await uploadCoverImage(file);
    packCoverUrlInput.value = url;
    updateCoverPreview(url);
    markDirty();
    toast('Cover image uploaded', 'success');
  } catch (err) {
    toast(err.message, 'error');
  } finally {
    packCoverFileInput.disabled = false;
    packCoverFileInput.value = '';
  }
});

packCoverUrlInput.addEventListener('input', () => {
  updateCoverPreview(packCoverUrlInput.value.trim());
});

addQuoteBtn.addEventListener('click', () => {
  addQuoteCard({ title: '', text: '', translations: {} }, false);
  updateQuoteCount();
  markDirty();
  quotesListEl.lastElementChild?.scrollIntoView({ behavior: 'smooth', block: 'center' });
});

addPackTransBtn.addEventListener('click', () => {
  const lang = prompt('Language code (e.g. es, fr, ar, fa):');
  if (!lang || !lang.trim()) return;
  addPackTranslation(lang.trim().toLowerCase(), '', '');
  markDirty();
});

// Collapse/Expand all quotes
let allCollapsed = false;
toggleAllBtn.addEventListener('click', () => {
  allCollapsed = !allCollapsed;
  quotesListEl.querySelectorAll('.quote-card').forEach(card => {
    card.classList.toggle('collapsed', allCollapsed);
  });
  toggleAllBtn.textContent = allCollapsed ? 'Expand All' : 'Collapse All';
});

// Add language to all quotes
addLangAllBtn.addEventListener('click', () => {
  const lang = prompt('Language code to add to ALL quotes (e.g. es, fr, ar, fa):');
  if (!lang || !lang.trim()) return;
  const code = lang.trim().toLowerCase();

  let added = 0;
  quotesListEl.querySelectorAll('.quote-card').forEach(card => {
    const container = card.querySelector('.translations-container');
    // Check if this language already exists
    const existing = container.querySelectorAll('.t-lang');
    const hasLang = Array.from(existing).some(el => el.value === code);
    if (!hasLang) {
      container.insertAdjacentHTML('beforeend', translationEntryHTML(code, '', ''));
      bindTranslationRemove(container.lastElementChild);
      added++;
    }
  });

  if (added > 0) {
    markDirty();
    toast(`Added "${code}" to ${added} quote(s)`, 'success');
  } else {
    toast(`All quotes already have "${code}"`, 'error');
  }
});

savePackBtn.addEventListener('click', handleSave);
deletePackBtn.addEventListener('click', handleDelete);

function addPackTranslation(lang, name, description) {
  const entry = document.createElement('div');
  entry.className = 'translation-entry';
  entry.innerHTML = `
    <div class="translation-header">
      <span class="lang-code">${esc(lang)}</span>
      <button class="btn-icon danger remove-translation" title="Remove translation">✕</button>
    </div>
    <input type="hidden" class="pt-lang" value="${esc(lang)}">
    <label>Name</label>
    <input type="text" class="pt-name" value="${esc(name || '')}">
    <label>Description</label>
    <textarea class="pt-desc" rows="2">${esc(description || '')}</textarea>
  `;
  entry.querySelector('.remove-translation').addEventListener('click', () => { entry.remove(); markDirty(); });
  entry.querySelectorAll('input, textarea').forEach(el => el.addEventListener('input', markDirty));
  packTransContainer.appendChild(entry);
}

function openEditor(pack) {
  editingPack = pack;
  clearDirty();
  allCollapsed = false;
  toggleAllBtn.textContent = 'Collapse All';
  packListView.classList.add('hidden');
  packEditor.classList.remove('hidden');
  packTransContainer.innerHTML = '';

  if (pack) {
    editorTitle.textContent = `Edit: ${pack.name}`;
    packIdInput.value = pack.id;
    packIdInput.disabled = true;
    packNameInput.value = pack.name;
    packDescInput.value = pack.description || '';
    packCoverUrlInput.value = pack.cover_url || '';
    updateCoverPreview(pack.cover_url || '');
    packCoverFileInput.value = '';
    packSortInput.value = pack.sort_order ?? 0;
    packVersionInput.value = pack.version || 1;
    packIsFreeInput.checked = pack.is_free !== false; // default to true
    deletePackBtn.classList.remove('hidden');

    // Load pack-level translations
    const trans = pack.translations || {};
    Object.entries(trans).forEach(([lang, t]) => {
      addPackTranslation(lang, t.name, t.description);
    });

    quotesListEl.innerHTML = '';
    (pack.quotes || []).forEach(q => addQuoteCard(q, true));
  } else {
    editorTitle.textContent = 'New Pack';
    packIdInput.value = '';
    packIdInput.disabled = false;
    packNameInput.value = '';
    packDescInput.value = '';
    packCoverUrlInput.value = '';
    updateCoverPreview('');
    packCoverFileInput.value = '';
    packSortInput.value = packs.length;
    packVersionInput.value = 1;
    packIsFreeInput.checked = true;
    deletePackBtn.classList.add('hidden');
    quotesListEl.innerHTML = '';
  }

  updateQuoteCount();
}

function closeEditor() {
  packEditor.classList.add('hidden');
  packListView.classList.remove('hidden');
  editingPack = null;
}

function updateQuoteCount() {
  quoteCountBadge.textContent = quotesListEl.children.length;
}

// ── Quote Cards ──

function addQuoteCard(quote, startCollapsed) {
  const idx = quotesListEl.children.length;
  const card = document.createElement('div');
  card.className = 'quote-card' + (startCollapsed ? ' collapsed' : '');
  card.draggable = true;

  const translations = quote.translations || {};
  const transHTML = Object.entries(translations).map(([lang, t]) =>
    translationEntryHTML(lang, t.title, t.text)
  ).join('');

  const titlePreview = quote.title || '(untitled)';

  card.innerHTML = `
    <div class="quote-header">
      <span class="quote-num">
        <span class="drag-handle" title="Drag to reorder">⠿</span>
        <span class="collapse-chevron">▼</span>
        Quote #${idx + 1}
        <span class="quote-title-preview">— ${esc(titlePreview)}</span>
      </span>
      <div class="quote-actions">
        <button class="btn-icon move-up" title="Move up">↑</button>
        <button class="btn-icon move-down" title="Move down">↓</button>
        <button class="btn-icon danger remove-quote" title="Remove quote">✕</button>
      </div>
    </div>
    <div class="quote-body">
      <label>Title</label>
      <input type="text" class="q-title" value="${esc(quote.title || '')}">
      <label>Text</label>
      <textarea class="q-text" rows="3">${esc(quote.text || '')}</textarea>
      <div class="translations-section">
        <div class="translations-header">
          <span>Translations</span>
          <button class="btn-icon add-translation" title="Add translation">+ lang</button>
        </div>
        <div class="translations-container">${transHTML}</div>
      </div>
    </div>
  `;

  // Toggle collapse on header click
  const header = card.querySelector('.quote-header');
  header.addEventListener('click', (e) => {
    // Don't toggle if clicking buttons
    if (e.target.closest('.quote-actions') || e.target.closest('.drag-handle')) return;
    card.classList.toggle('collapsed');
  });

  // Track dirty on quote inputs
  card.querySelectorAll('input, textarea').forEach(el => {
    el.addEventListener('input', markDirty);
  });

  // Auto-title: when text field loses focus and title is empty, generate title
  const textArea = card.querySelector('.q-text');
  const titleInput = card.querySelector('.q-title');
  textArea.addEventListener('blur', () => {
    if (!titleInput.value.trim() && textArea.value.trim()) {
      const words = textArea.value.trim().split(/\s+/);
      titleInput.value = words.slice(0, 6).join(' ') + (words.length > 6 ? '...' : '');
      // Update the collapsed preview
      updateTitlePreview(card);
      markDirty();
    }
  });

  // Update preview when title changes
  titleInput.addEventListener('input', () => updateTitlePreview(card));

  card.querySelector('.remove-quote').addEventListener('click', () => {
    card.remove();
    renumberQuotes();
    updateQuoteCount();
    markDirty();
  });

  card.querySelector('.move-up').addEventListener('click', (e) => {
    e.stopPropagation();
    const prev = card.previousElementSibling;
    if (prev) {
      quotesListEl.insertBefore(card, prev);
      renumberQuotes();
      markDirty();
    }
  });

  card.querySelector('.move-down').addEventListener('click', (e) => {
    e.stopPropagation();
    const next = card.nextElementSibling;
    if (next) {
      quotesListEl.insertBefore(next, card);
      renumberQuotes();
      markDirty();
    }
  });

  card.querySelector('.add-translation').addEventListener('click', () => {
    const lang = prompt('Language code (e.g. es, fr, ar, fa):');
    if (!lang || !lang.trim()) return;
    const container = card.querySelector('.translations-container');
    container.insertAdjacentHTML('beforeend', translationEntryHTML(lang.trim().toLowerCase(), '', ''));
    const newEntry = container.lastElementChild;
    bindTranslationRemove(newEntry);
    newEntry.querySelectorAll('input, textarea').forEach(el => el.addEventListener('input', markDirty));
    markDirty();
  });

  // Drag and drop
  card.addEventListener('dragstart', (e) => {
    card.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
  });

  card.addEventListener('dragend', () => {
    card.classList.remove('dragging');
    document.querySelectorAll('.quote-card.drag-over').forEach(c => c.classList.remove('drag-over'));
    renumberQuotes();
  });

  card.addEventListener('dragover', (e) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    const dragging = document.querySelector('.quote-card.dragging');
    if (dragging && dragging !== card) {
      card.classList.add('drag-over');
      const rect = card.getBoundingClientRect();
      const mid = rect.top + rect.height / 2;
      if (e.clientY < mid) {
        quotesListEl.insertBefore(dragging, card);
      } else {
        quotesListEl.insertBefore(dragging, card.nextSibling);
      }
      markDirty();
    }
  });

  card.addEventListener('dragleave', () => card.classList.remove('drag-over'));
  card.addEventListener('drop', (e) => {
    e.preventDefault();
    card.classList.remove('drag-over');
  });

  card.querySelectorAll('.translation-entry').forEach(entry => {
    bindTranslationRemove(entry);
    entry.querySelectorAll('input, textarea').forEach(el => el.addEventListener('input', markDirty));
  });
  quotesListEl.appendChild(card);
}

function updateTitlePreview(card) {
  const titleInput = card.querySelector('.q-title');
  const preview = card.querySelector('.quote-title-preview');
  const val = titleInput.value.trim();
  preview.textContent = val ? `— ${val}` : '— (untitled)';
}

function translationEntryHTML(lang, title, text) {
  return `
    <div class="translation-entry">
      <div class="translation-header">
        <span class="lang-code">${esc(lang)}</span>
        <button class="btn-icon danger remove-translation" title="Remove translation">✕</button>
      </div>
      <input type="hidden" class="t-lang" value="${esc(lang)}">
      <label>Title</label>
      <input type="text" class="t-title" value="${esc(title || '')}">
      <label>Text</label>
      <textarea class="t-text" rows="2">${esc(text || '')}</textarea>
    </div>
  `;
}

function bindTranslationRemove(entry) {
  entry.querySelector('.remove-translation')?.addEventListener('click', () => {
    entry.remove();
    markDirty();
  });
}

function renumberQuotes() {
  quotesListEl.querySelectorAll('.quote-card').forEach((card, i) => {
    const titleInput = card.querySelector('.q-title');
    const titleVal = titleInput ? titleInput.value.trim() : '';
    const preview = titleVal || '(untitled)';
    card.querySelector('.quote-num').innerHTML = `
      <span class="drag-handle" title="Drag to reorder">⠿</span>
      <span class="collapse-chevron">▼</span>
      Quote #${i + 1}
      <span class="quote-title-preview">— ${esc(preview)}</span>
    `;
  });
}

// ── Collect Data ──

function collectPackData() {
  const id = packIdInput.value.trim();
  const name = packNameInput.value.trim();

  if (!id) throw new Error('Pack ID is required.');
  if (!name) throw new Error('Pack name is required.');
  if (!/^[a-z0-9-]+$/.test(id)) throw new Error('Pack ID must be lowercase alphanumeric with dashes only.');

  const quotes = [];
  quotesListEl.querySelectorAll('.quote-card').forEach(card => {
    const title = card.querySelector('.q-title').value.trim();
    const text = card.querySelector('.q-text').value.trim();
    if (!text) return;

    const translations = {};
    card.querySelectorAll('.translation-entry').forEach(entry => {
      const lang = entry.querySelector('.t-lang').value.trim();
      const tTitle = entry.querySelector('.t-title').value.trim();
      const tText = entry.querySelector('.t-text').value.trim();
      if (lang && tText) {
        translations[lang] = { title: tTitle, text: tText };
      }
    });

    const quote = { title, text };
    if (Object.keys(translations).length > 0) {
      quote.translations = translations;
    }
    quotes.push(quote);
  });

  // Collect pack-level translations
  const packTrans = {};
  packTransContainer.querySelectorAll('.translation-entry').forEach(entry => {
    const lang = entry.querySelector('.pt-lang').value.trim();
    const tName = entry.querySelector('.pt-name').value.trim();
    const tDesc = entry.querySelector('.pt-desc').value.trim();
    if (lang && (tName || tDesc)) {
      packTrans[lang] = { name: tName, description: tDesc };
    }
  });

  // Auto-increment version when editing an existing pack
  let version = parseInt(packVersionInput.value) || 1;
  if (editingPack) {
    version = (editingPack.version || 1) + 1;
  }

  return {
    id,
    name,
    description: packDescInput.value.trim(),
    cover_url: packCoverUrlInput.value.trim() || null,
    cover_search_query: null,
    sort_order: parseInt(packSortInput.value) || 0,
    version,
    translations: Object.keys(packTrans).length > 0 ? packTrans : null,
    is_free: packIsFreeInput.checked,
    quotes,
  };
}

// ── Save ──

async function handleSave() {
  try {
    const pack = collectPackData();
    savePackBtn.textContent = 'Saving…';
    savePackBtn.disabled = true;

    await upsertPack(pack);
    clearDirty();
    toast('Pack saved!', 'success');
    await loadPacks();
    closeEditor();
  } catch (e) {
    toast(e.message, 'error');
  } finally {
    savePackBtn.textContent = 'Save Pack';
    savePackBtn.disabled = false;
  }
}

// ── Delete ──

async function handleDelete() {
  if (!editingPack) return;

  showConfirm(
    'Delete Pack',
    `Are you sure you want to delete "${editingPack.name}"? This cannot be undone.`,
    async () => {
      try {
        await deletePack(editingPack.id);
        clearDirty();
        toast('Pack deleted.', 'success');
        await loadPacks();
        closeEditor();
      } catch (e) {
        toast(e.message, 'error');
      }
    }
  );
}

// ── Confirm Modal ──

const confirmModal = document.getElementById('confirm-modal');
const confirmTitle = document.getElementById('confirm-title');
const confirmMessage = document.getElementById('confirm-message');
const confirmCancel = document.getElementById('confirm-cancel');
const confirmOk = document.getElementById('confirm-ok');
let confirmCallback = null;

function showConfirm(title, message, onConfirm) {
  confirmTitle.textContent = title;
  confirmMessage.textContent = message;
  confirmCallback = onConfirm;
  confirmModal.classList.remove('hidden');
}

confirmCancel.addEventListener('click', () => confirmModal.classList.add('hidden'));
confirmOk.addEventListener('click', () => {
  confirmModal.classList.add('hidden');
  if (confirmCallback) confirmCallback();
});

// ── Toast ──

function toast(message, type = 'success') {
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.textContent = message;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3000);
}

// ── Utils ──

function esc(str) {
  if (!str) return '';
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// ══════════════════════════════════════════════════
// ── Languages ──
// ══════════════════════════════════════════════════

const LANGUAGES_TABLE = 'languages';
let languages = [];
let editingLang = null;

const langListEl = document.getElementById('languages-list');
const langTotalBadge = document.getElementById('lang-total');
const langEmptyEl = document.getElementById('lang-empty');
const addLangBtn = document.getElementById('add-lang-btn');
const langModal = document.getElementById('lang-modal');
const langModalTitle = document.getElementById('lang-modal-title');
const langCodeInput = document.getElementById('lang-code-input');
const langNameInput = document.getElementById('lang-name-input');
const langColorInput = document.getElementById('lang-color-input');
const langColorHex = document.getElementById('lang-color-hex');
const langTextColorInput = document.getElementById('lang-text-color-input');
const langTextColorHex = document.getElementById('lang-text-color-hex');
const langPreviewPill = document.getElementById('lang-preview-pill');
const langModalCancel = document.getElementById('lang-modal-cancel');
const langModalDelete = document.getElementById('lang-modal-delete');
const langModalSave = document.getElementById('lang-modal-save');

function updateLangPreview() {
  const bg = langColorInput.value;
  const fg = langTextColorInput.value;
  const name = langCodeInput.value.toUpperCase() || 'Preview';
  langPreviewPill.style.background = bg;
  langPreviewPill.style.color = fg;
  langPreviewPill.textContent = name;
}

langColorInput.addEventListener('input', () => { langColorHex.value = langColorInput.value; updateLangPreview(); });
langColorHex.addEventListener('input', () => { langColorInput.value = langColorHex.value; updateLangPreview(); });
langTextColorInput.addEventListener('input', () => { langTextColorHex.value = langTextColorInput.value; updateLangPreview(); });
langTextColorHex.addEventListener('input', () => { langTextColorInput.value = langTextColorHex.value; updateLangPreview(); });
langCodeInput.addEventListener('input', updateLangPreview);

async function loadLanguages() {
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${LANGUAGES_TABLE}?select=*&order=code.asc`,
      { headers: headers() }
    );
    if (!res.ok) throw new Error(`Failed: ${res.status}`);
    languages = await res.json();
    renderLanguages();
  } catch (e) {
    console.error('loadLanguages', e);
  }
}

function renderLanguages() {
  langTotalBadge.textContent = languages.length;
  langEmptyEl.classList.toggle('hidden', languages.length > 0);
  langListEl.innerHTML = '';
  languages.forEach(lang => {
    const card = document.createElement('div');
    card.className = 'lang-card';
    card.innerHTML = `
      <span class="lang-pill" style="background:${esc(lang.color)};color:${esc(lang.text_color)}">${esc(lang.code.toUpperCase())}</span>
      <div class="lang-info">
        <h4>${esc(lang.display_name)}</h4>
        <span>${esc(lang.code)}</span>
      </div>
    `;
    card.addEventListener('click', () => openLangModal(lang));
    langListEl.appendChild(card);
  });
}

function openLangModal(lang) {
  editingLang = lang || null;
  langModalTitle.textContent = lang ? `Edit: ${lang.display_name}` : 'Add Language';
  langCodeInput.value = lang ? lang.code : '';
  langCodeInput.disabled = !!lang;
  langNameInput.value = lang ? lang.display_name : '';
  langColorInput.value = lang ? lang.color : '#6366f1';
  langColorHex.value = lang ? lang.color : '#6366f1';
  langTextColorInput.value = lang ? lang.text_color : '#ffffff';
  langTextColorHex.value = lang ? lang.text_color : '#ffffff';
  langModalDelete.classList.toggle('hidden', !lang);
  updateLangPreview();
  langModal.classList.remove('hidden');
}

addLangBtn.addEventListener('click', () => openLangModal(null));
langModalCancel.addEventListener('click', () => langModal.classList.add('hidden'));

langModalSave.addEventListener('click', async () => {
  const code = langCodeInput.value.trim().toLowerCase();
  const display_name = langNameInput.value.trim();
  if (!code || !display_name) { toast('Code and name are required', 'error'); return; }

  const row = {
    code,
    display_name,
    color: langColorInput.value,
    text_color: langTextColorInput.value,
  };

  try {
    langModalSave.disabled = true;
    langModalSave.textContent = 'Saving...';
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${LANGUAGES_TABLE}?on_conflict=code`,
      {
        method: 'POST',
        headers: { ...headers(), 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates' },
        body: JSON.stringify(row),
      }
    );
    if (!res.ok) throw new Error(`Save failed: ${res.status}`);
    langModal.classList.add('hidden');
    toast('Language saved', 'success');
    await loadLanguages();
  } catch (e) {
    toast(e.message, 'error');
  } finally {
    langModalSave.disabled = false;
    langModalSave.textContent = 'Save';
  }
});

langModalDelete.addEventListener('click', async () => {
  if (!editingLang) return;
  if (!confirm(`Delete language "${editingLang.display_name}"?`)) return;
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${LANGUAGES_TABLE}?code=eq.${encodeURIComponent(editingLang.code)}`,
      { method: 'DELETE', headers: headers() }
    );
    if (!res.ok) throw new Error(`Delete failed: ${res.status}`);
    langModal.classList.add('hidden');
    toast('Language deleted', 'success');
    await loadLanguages();
  } catch (e) {
    toast(e.message, 'error');
  }
});

// ══════════════════════════════════════════════════
// ── Tab Navigation ──
// ══════════════════════════════════════════════════

const tabBtns = document.querySelectorAll('.tab-btn');
const packsViews = ['pack-list-view', 'pack-editor'];
const recordingsViews = ['recordings-list-view', 'recording-detail'];
const equivalencesViews = ['equivalences-view'];
const languagesViews = ['languages-view'];
const supportViews = ['support-view', 'support-detail'];

let activeTab = 'packs';

tabBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    if (dirty) {
      if (!confirm('You have unsaved changes. Switch tab?')) return;
      clearDirty();
    }
    activeTab = btn.dataset.tab;
    tabBtns.forEach(b => b.classList.toggle('active', b.dataset.tab === activeTab));
    switchTab();
  });
});

function switchTab() {
  // Hide all views
  [...packsViews, ...recordingsViews, ...equivalencesViews, ...languagesViews, ...supportViews].forEach(id =>
    document.getElementById(id).classList.add('hidden')
  );

  if (activeTab === 'packs') {
    document.getElementById('pack-list-view').classList.remove('hidden');
  } else if (activeTab === 'recordings') {
    document.getElementById('recordings-list-view').classList.remove('hidden');
    if (recordings.length === 0) loadRecordings();
  } else if (activeTab === 'equivalences') {
    document.getElementById('equivalences-view').classList.remove('hidden');
    if (equivalences.length === 0) loadEquivalences();
  } else if (activeTab === 'languages') {
    document.getElementById('languages-view').classList.remove('hidden');
    if (languages.length === 0) loadLanguages();
  } else if (activeTab === 'support') {
    document.getElementById('support-view').classList.remove('hidden');
    if (supportTickets.length === 0) loadSupportTickets();
  }
}

// ══════════════════════════════════════════════════
// ── Recordings ──
// ══════════════════════════════════════════════════

const RECORDINGS_TABLE = 'recordings';
const FLAGS_TABLE = 'flags';
const STORAGE_BASE = `${SUPABASE_URL}/storage/v1/object/public/recordings`;

let recordings = [];
let recordingFlags = {}; // recording_id -> [flag, ...]
let recordingFilter = 'all';
let recordingOffset = 0;
const RECORDINGS_PAGE_SIZE = 50;

const recordingsListView = document.getElementById('recordings-list-view');
const recordingsListEl = document.getElementById('recordings-list');
const recordingSearchInput = document.getElementById('recording-search');
const recordingsTotalBadge = document.getElementById('recordings-total');
const loadMoreBtn = document.getElementById('load-more-btn');
const loadMoreContainer = document.getElementById('recordings-load-more');

// Filter pills
document.querySelectorAll('.filter-pill').forEach(pill => {
  pill.addEventListener('click', () => {
    document.querySelectorAll('.filter-pill').forEach(p => p.classList.remove('active'));
    pill.classList.add('active');
    recordingFilter = pill.dataset.filter;
    renderRecordingsList();
  });
});

recordingSearchInput.addEventListener('input', renderRecordingsList);

loadMoreBtn.addEventListener('click', () => loadRecordings(true));

async function fetchRecordings(offset = 0) {
  const params = new URLSearchParams({
    select: '*',
    order: 'created_at.desc',
    offset: offset.toString(),
    limit: RECORDINGS_PAGE_SIZE.toString(),
  });
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${RECORDINGS_TABLE}?${params}`,
    { headers: headers() }
  );
  if (!res.ok) throw new Error(`Fetch recordings failed: ${res.status}`);
  return res.json();
}

async function fetchAllFlags() {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${FLAGS_TABLE}?select=*&order=created_at.desc`,
    { headers: headers() }
  );
  if (!res.ok) throw new Error(`Fetch flags failed: ${res.status}`);
  const flags = await res.json();
  // Group by recording_id
  const grouped = {};
  flags.forEach(f => {
    if (!grouped[f.recording_id]) grouped[f.recording_id] = [];
    grouped[f.recording_id].push(f);
  });
  return grouped;
}

async function loadRecordings(append = false) {
  if (!append) {
    recordingOffset = 0;
    recordingsListEl.innerHTML = '<div class="loading">Loading recordings…</div>';
  }

  try {
    const [recs, flags] = await Promise.all([
      fetchRecordings(recordingOffset),
      append ? Promise.resolve(recordingFlags) : fetchAllFlags(),
    ]);

    if (append) {
      recordings = recordings.concat(recs);
    } else {
      recordings = recs;
      recordingFlags = flags;
    }

    recordingOffset += recs.length;
    loadMoreContainer.classList.toggle('hidden', recs.length < RECORDINGS_PAGE_SIZE);

    renderRecordingsList();
  } catch (e) {
    if (!append) {
      recordingsListEl.innerHTML = `<div class="empty-state"><p>Failed to load recordings: ${esc(e.message)}</p></div>`;
    } else {
      toast(e.message, 'error');
    }
  }
}

function renderRecordingsList() {
  const query = recordingSearchInput.value.trim().toLowerCase();

  let filtered = recordings;

  // Search filter
  if (query) {
    filtered = filtered.filter(r =>
      (r.quote_title || '').toLowerCase().includes(query) ||
      (r.uploader_name || '').toLowerCase().includes(query) ||
      (r.language || '').toLowerCase().includes(query) ||
      (r.id || '').toLowerCase().includes(query)
    );
  }

  // Flag filter
  if (recordingFilter === 'flagged') {
    filtered = filtered.filter(r => recordingFlags[r.id]?.length > 0);
  } else if (recordingFilter === 'unreviewed') {
    filtered = filtered.filter(r => {
      const flags = recordingFlags[r.id];
      return flags && flags.some(f => !f.status || f.status === 'pending');
    });
  }

  recordingsTotalBadge.textContent = filtered.length;

  if (filtered.length === 0) {
    recordingsListEl.innerHTML = recordingFilter !== 'all'
      ? '<div class="empty-state"><p>No recordings match this filter.</p></div>'
      : '<div class="empty-state"><p>No recordings found.</p></div>';
    return;
  }

  recordingsListEl.innerHTML = filtered.map(r => {
    const flags = recordingFlags[r.id] || [];
    const hasUnreviewed = flags.some(f => !f.status || f.status === 'pending');
    const isFlagged = flags.length > 0;
    const cardClass = hasUnreviewed ? 'flagged-unreviewed' : (isFlagged ? 'flagged' : '');
    const duration = r.duration_seconds ? `${Math.round(r.duration_seconds)}s` : '—';
    const date = r.created_at ? new Date(r.created_at).toLocaleDateString() : '—';

    return `
      <div class="recording-card ${cardClass}" data-id="${esc(r.id)}">
        <div class="recording-card-info">
          <h4>${esc(r.quote_title || '(untitled)')}</h4>
          <div class="recording-meta">
            <span>by ${esc(r.uploader_name || 'Anonymous')}</span>
            <span>${esc(r.language || 'en')}</span>
            <span>${duration}</span>
            <span>${date}</span>
          </div>
        </div>
        <div class="recording-card-badges">
          ${hasUnreviewed ? `<span class="badge-flag-unreviewed">${flags.filter(f => !f.status || f.status === 'pending').length} unreviewed</span>` : ''}
          ${isFlagged && !hasUnreviewed ? `<span class="badge-flag">${flags.length} flag${flags.length > 1 ? 's' : ''}</span>` : ''}
        </div>
      </div>
    `;
  }).join('');

  recordingsListEl.querySelectorAll('.recording-card').forEach(card => {
    card.addEventListener('click', () => {
      const rec = recordings.find(r => r.id === card.dataset.id);
      if (rec) openRecordingDetail(rec);
    });
  });
}

// ── Recording Detail ──

const recordingDetail = document.getElementById('recording-detail');
const recordingBackBtn = document.getElementById('recording-back-btn');
const deleteRecordingBtn = document.getElementById('delete-recording-btn');
const recIdInput = document.getElementById('rec-id');
const recQuoteTitleInput = document.getElementById('rec-quote-title');
const recUploaderInput = document.getElementById('rec-uploader');
const recLanguageInput = document.getElementById('rec-language');
const recDurationInput = document.getElementById('rec-duration');
const recCreatedAtInput = document.getElementById('rec-created-at');
const recUserIdInput = document.getElementById('rec-user-id');
const recAudio = document.getElementById('rec-audio');
const recFlagsList = document.getElementById('rec-flags-list');
const recNoFlags = document.getElementById('rec-no-flags');
const recFlagCountBadge = document.getElementById('rec-flag-count');
const recordingDetailTitle = document.getElementById('recording-detail-title');
const saveRecordingBtn = document.getElementById('save-recording-btn');

let viewingRecording = null;

recordingBackBtn.addEventListener('click', () => {
  recordingDetail.classList.add('hidden');
  recordingsListView.classList.remove('hidden');
  recAudio.pause();
  recAudio.src = '';
  viewingRecording = null;
});

deleteRecordingBtn.addEventListener('click', () => {
  if (!viewingRecording) return;
  showConfirm(
    'Delete Recording',
    `Delete this recording by "${viewingRecording.uploader_name || 'Anonymous'}"? This also removes the audio file and cannot be undone.`,
    async () => {
      try {
        // Delete from storage
        if (viewingRecording.file_path) {
          await fetch(`${SUPABASE_URL}/storage/v1/object/recordings/${viewingRecording.file_path}`, {
            method: 'DELETE',
            headers: { 'apikey': ANON_KEY, 'Authorization': `Bearer ${accessToken}` },
          });
        }
        // Delete flags for this recording
        await fetch(
          `${SUPABASE_URL}/rest/v1/${FLAGS_TABLE}?recording_id=eq.${viewingRecording.id}`,
          { method: 'DELETE', headers: headers() }
        );
        // Delete recording row
        await fetch(
          `${SUPABASE_URL}/rest/v1/${RECORDINGS_TABLE}?id=eq.${viewingRecording.id}`,
          { method: 'DELETE', headers: headers() }
        );

        toast('Recording deleted.', 'success');
        recordings = recordings.filter(r => r.id !== viewingRecording.id);
        delete recordingFlags[viewingRecording.id];
        recordingDetail.classList.add('hidden');
        recordingsListView.classList.remove('hidden');
        recAudio.pause();
        recAudio.src = '';
        viewingRecording = null;
        renderRecordingsList();
      } catch (e) {
        toast(`Delete failed: ${e.message}`, 'error');
      }
    }
  );
});

saveRecordingBtn.addEventListener('click', async () => {
  if (!viewingRecording) return;
  const updates = {
    quote_title: recQuoteTitleInput.value.trim(),
    uploader_name: recUploaderInput.value.trim(),
    language: recLanguageInput.value.trim() || 'en',
  };

  try {
    saveRecordingBtn.textContent = 'Saving…';
    saveRecordingBtn.disabled = true;
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${RECORDINGS_TABLE}?id=eq.${viewingRecording.id}`,
      { method: 'PATCH', headers: headers(), body: JSON.stringify(updates) }
    );
    if (!res.ok) throw new Error(`Save failed: ${res.status}`);

    // Update local state
    Object.assign(viewingRecording, updates);
    recordingDetailTitle.textContent = updates.quote_title || '(untitled)';
    renderRecordingsList();
    toast('Recording updated.', 'success');
  } catch (e) {
    toast(e.message, 'error');
  } finally {
    saveRecordingBtn.textContent = 'Save Changes';
    saveRecordingBtn.disabled = false;
  }
});

function openRecordingDetail(rec) {
  viewingRecording = rec;
  recordingsListView.classList.add('hidden');
  recordingDetail.classList.remove('hidden');

  recordingDetailTitle.textContent = rec.quote_title || '(untitled)';
  recIdInput.value = rec.id;
  recQuoteTitleInput.value = rec.quote_title || '';
  recUploaderInput.value = rec.uploader_name || 'Anonymous';
  recLanguageInput.value = rec.language || 'en';
  recDurationInput.value = rec.duration_seconds ? `${Math.round(rec.duration_seconds)}s` : '—';
  recCreatedAtInput.value = rec.created_at ? new Date(rec.created_at).toLocaleString() : '—';
  recUserIdInput.value = rec.user_id || '(anonymous)';

  // Audio
  if (rec.file_path) {
    recAudio.src = `${STORAGE_BASE}/${rec.file_path}`;
  } else {
    recAudio.src = '';
  }

  // Flags
  renderRecordingFlags(rec.id);
}

function renderRecordingFlags(recordingId) {
  const flags = recordingFlags[recordingId] || [];
  recFlagCountBadge.textContent = flags.length;

  if (flags.length === 0) {
    recFlagsList.innerHTML = '';
    recNoFlags.classList.remove('hidden');
    return;
  }

  recNoFlags.classList.add('hidden');
  recFlagsList.innerHTML = flags.map(f => {
    const status = f.status || 'pending';
    const statusClass = `flag-status-${status}`;
    const statusLabel = status.charAt(0).toUpperCase() + status.slice(1);
    const date = f.created_at ? new Date(f.created_at).toLocaleString() : '—';

    return `
      <div class="flag-card" data-flag-id="${esc(f.id)}">
        <div class="flag-card-header">
          <span class="flag-date">${date}</span>
          <span class="flag-status ${statusClass}">${statusLabel}</span>
        </div>
        <div class="flag-reason">${esc(f.reason || '(no reason given)')}</div>
        <div class="flag-actions">
          ${status === 'pending' ? `
            <button class="btn-primary flag-action" data-status="reviewed">Mark Reviewed</button>
            <button class="btn-secondary flag-action" data-status="dismissed">Dismiss</button>
          ` : `
            <button class="btn-secondary flag-action" data-status="pending">Reopen</button>
          `}
        </div>
      </div>
    `;
  }).join('');

  recFlagsList.querySelectorAll('.flag-action').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const flagCard = btn.closest('.flag-card');
      const flagId = flagCard.dataset.flagId;
      const newStatus = btn.dataset.status;
      await updateFlagStatus(flagId, newStatus, recordingId);
    });
  });
}

// ══════════════════════════════════════════════════
// ── Equivalences ──
// ══════════════════════════════════════════════════

const EQUIVALENCES_TABLE = 'equivalences';

let equivalences = [];

const equivTbody = document.getElementById('equiv-tbody');
const equivTotalBadge = document.getElementById('equiv-total');
const equivSearchInput = document.getElementById('equiv-search');
const equivSortSelect = document.getElementById('equiv-sort');
const equivEmpty = document.getElementById('equiv-empty');
const addEquivBtn = document.getElementById('add-equiv-btn');
const addEquivModal = document.getElementById('add-equiv-modal');
const addEquivCancel = document.getElementById('add-equiv-cancel');
const addEquivSave = document.getElementById('add-equiv-save');
const newEquivExpected = document.getElementById('new-equiv-expected');
const newEquivSpoken = document.getElementById('new-equiv-spoken');

equivSearchInput.addEventListener('input', renderEquivalences);
equivSortSelect.addEventListener('change', renderEquivalences);

addEquivBtn.addEventListener('click', () => {
  newEquivExpected.value = '';
  newEquivSpoken.value = '';
  addEquivModal.classList.remove('hidden');
  newEquivExpected.focus();
});

addEquivCancel.addEventListener('click', () => addEquivModal.classList.add('hidden'));

addEquivSave.addEventListener('click', async () => {
  const expected = newEquivExpected.value.trim().toLowerCase();
  const spoken = newEquivSpoken.value.trim().toLowerCase();
  if (!expected || !spoken) { toast('Both fields are required.', 'error'); return; }
  if (expected === spoken) { toast('Words must be different.', 'error'); return; }

  try {
    addEquivSave.textContent = 'Adding…';
    addEquivSave.disabled = true;

    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${EQUIVALENCES_TABLE}`,
      {
        method: 'POST',
        headers: { ...headers(), 'Prefer': 'return=representation' },
        body: JSON.stringify({ expected_word: expected, spoken_word: spoken, report_count: 1 }),
      }
    );
    if (res.status === 409) {
      toast('This equivalence already exists.', 'error');
      return;
    }
    if (!res.ok) throw new Error(`Insert failed: ${res.status}`);

    const [created] = await res.json();
    equivalences.unshift(created);
    renderEquivalences();
    addEquivModal.classList.add('hidden');
    toast('Equivalence added.', 'success');
  } catch (e) {
    toast(e.message, 'error');
  } finally {
    addEquivSave.textContent = 'Add';
    addEquivSave.disabled = false;
  }
});

async function loadEquivalences() {
  equivTbody.innerHTML = '';
  equivEmpty.classList.add('hidden');
  equivTotalBadge.textContent = '…';

  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${EQUIVALENCES_TABLE}?select=*&order=created_at.desc`,
      { headers: headers() }
    );
    if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
    equivalences = await res.json();
    renderEquivalences();
  } catch (e) {
    equivTbody.innerHTML = '';
    equivEmpty.classList.remove('hidden');
    equivEmpty.querySelector('p').textContent = `Failed to load: ${e.message}`;
  }
}

function renderEquivalences() {
  const query = equivSearchInput.value.trim().toLowerCase();
  const sortBy = equivSortSelect.value;

  let filtered = equivalences;
  if (query) {
    filtered = filtered.filter(eq =>
      eq.expected_word.includes(query) || eq.spoken_word.includes(query)
    );
  }

  // Sort
  filtered = [...filtered].sort((a, b) => {
    if (sortBy === 'report_count') return (b.report_count || 1) - (a.report_count || 1);
    if (sortBy === 'expected_word') return a.expected_word.localeCompare(b.expected_word);
    return new Date(b.created_at) - new Date(a.created_at);
  });

  equivTotalBadge.textContent = filtered.length;

  if (filtered.length === 0) {
    equivTbody.innerHTML = '';
    equivEmpty.classList.remove('hidden');
    equivEmpty.querySelector('p').textContent = query
      ? 'No equivalences match your search.'
      : 'No equivalences yet.';
    return;
  }

  equivEmpty.classList.add('hidden');
  equivTbody.innerHTML = filtered.map(eq => {
    const date = eq.created_at ? new Date(eq.created_at).toLocaleDateString() : '—';
    return `
      <tr data-id="${esc(eq.id)}">
        <td><span class="equiv-word">${esc(eq.expected_word)}</span></td>
        <td>${esc(eq.spoken_word)}</td>
        <td><span class="equiv-count">${eq.report_count || 1}</span></td>
        <td>${date}</td>
        <td><button class="btn-icon danger delete-equiv" title="Delete">✕</button></td>
      </tr>
    `;
  }).join('');

  equivTbody.querySelectorAll('.delete-equiv').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const tr = btn.closest('tr');
      const id = tr.dataset.id;
      const eq = equivalences.find(eq => eq.id === id);
      showConfirm(
        'Delete Equivalence',
        `Delete "${eq?.expected_word}" → "${eq?.spoken_word}"?`,
        async () => {
          try {
            const res = await fetch(
              `${SUPABASE_URL}/rest/v1/${EQUIVALENCES_TABLE}?id=eq.${id}`,
              { method: 'DELETE', headers: headers() }
            );
            if (!res.ok) throw new Error(`Delete failed: ${res.status}`);
            equivalences = equivalences.filter(eq => eq.id !== id);
            renderEquivalences();
            toast('Equivalence deleted.', 'success');
          } catch (e) {
            toast(e.message, 'error');
          }
        }
      );
    });
  });
}

// ── Flag Status ──

async function updateFlagStatus(flagId, status, recordingId) {
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${FLAGS_TABLE}?id=eq.${flagId}`,
      {
        method: 'PATCH',
        headers: headers(),
        body: JSON.stringify({ status }),
      }
    );
    if (!res.ok) throw new Error(`Update failed: ${res.status}`);

    // Update local state
    const flags = recordingFlags[recordingId];
    if (flags) {
      const flag = flags.find(f => f.id === flagId);
      if (flag) flag.status = status;
    }

    renderRecordingFlags(recordingId);
    toast(`Flag ${status}.`, 'success');
  } catch (e) {
    toast(e.message, 'error');
  }
}

// ══════════════════════════════════════════════════
// ── Support Tickets ──
// ══════════════════════════════════════════════════

const SUPPORT_TABLE = 'support_tickets';
let supportTickets = [];
let supportFilter = 'all';
let supportReasonFilter = 'all';
let supportSearchQuery = '';
let viewingTicket = null;

const REASON_LABELS = {
  feature_request: 'Feature Request',
  quote_pack_request: 'Quote Pack Request',
  bug_report: 'Bug Report',
  awesome: "Hey You're Awesome",
  other: 'Other',
};

const REASON_BADGE_CLASS = {
  feature_request: 'badge-free',
  quote_pack_request: 'badge-pro',
  bug_report: 'badge-flag-unreviewed',
  awesome: 'badge-free',
  other: '',
};

async function loadSupportTickets() {
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${SUPPORT_TABLE}?select=*&order=created_at.desc`,
      { headers: headers() }
    );
    if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
    supportTickets = await res.json();
    renderSupportTickets();
  } catch (e) {
    toast(e.message, 'error');
  }
}

function filteredSupportTickets() {
  return supportTickets.filter(t => {
    if (supportFilter === 'unread' && t.is_read) return false;
    if (supportFilter === 'read' && !t.is_read) return false;
    if (supportReasonFilter !== 'all' && t.reason !== supportReasonFilter) return false;
    if (supportSearchQuery) {
      const q = supportSearchQuery.toLowerCase();
      const match = (t.email || '').toLowerCase().includes(q) ||
                    (t.message || '').toLowerCase().includes(q);
      if (!match) return false;
    }
    return true;
  });
}

function renderSupportTickets() {
  const list = document.getElementById('support-list');
  const empty = document.getElementById('support-empty');
  const total = document.getElementById('support-total');
  const filtered = filteredSupportTickets();

  const unreadCount = supportTickets.filter(t => !t.is_read).length;
  total.textContent = unreadCount > 0 ? `${supportTickets.length} (${unreadCount} unread)` : supportTickets.length;

  if (filtered.length === 0) {
    list.innerHTML = '';
    empty.classList.remove('hidden');
    return;
  }
  empty.classList.add('hidden');

  list.innerHTML = filtered.map(t => {
    const date = new Date(t.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    const reasonLabel = REASON_LABELS[t.reason] || t.reason;
    const badgeClass = REASON_BADGE_CLASS[t.reason] || '';
    const readClass = t.is_read ? '' : 'border-left: 3px solid var(--primary);';
    const preview = (t.message || '').substring(0, 100) + ((t.message || '').length > 100 ? '...' : '');

    return `<div class="recording-card" style="${readClass}" onclick="viewTicket('${t.id}')">
      <div class="recording-card-info">
        <h4>${escapeHtml(t.email || 'No email')}</h4>
        <div class="recording-meta">
          <span>${date}</span>
          <span>${t.app_version || ''}</span>
          <span>${t.device_info || ''}</span>
        </div>
        <p style="margin-top:6px;font-size:0.8125rem;color:var(--text2)">${escapeHtml(preview)}</p>
      </div>
      <div class="recording-card-badges">
        ${badgeClass ? `<span class="${badgeClass}">${reasonLabel}</span>` : `<span class="badge">${reasonLabel}</span>`}
        ${!t.is_read ? '<span class="badge-flag-unreviewed">NEW</span>' : ''}
      </div>
    </div>`;
  }).join('');
}

function viewTicket(id) {
  viewingTicket = supportTickets.find(t => t.id === id);
  if (!viewingTicket) return;

  document.getElementById('support-view').classList.add('hidden');
  document.getElementById('support-detail').classList.remove('hidden');

  document.getElementById('ticket-reason-title').textContent = REASON_LABELS[viewingTicket.reason] || viewingTicket.reason;
  document.getElementById('ticket-email').value = viewingTicket.email || '';
  document.getElementById('ticket-reason').value = REASON_LABELS[viewingTicket.reason] || viewingTicket.reason;
  document.getElementById('ticket-message').value = viewingTicket.message || '';
  document.getElementById('ticket-app-version').value = viewingTicket.app_version || '';
  document.getElementById('ticket-device').value = viewingTicket.device_info || '';
  document.getElementById('ticket-user-id').value = viewingTicket.user_id || 'Anonymous';
  document.getElementById('ticket-created-at').value = new Date(viewingTicket.created_at).toLocaleString();

  const readBadge = document.getElementById('ticket-read-badge');
  readBadge.innerHTML = viewingTicket.is_read
    ? '<span class="badge">Read</span>'
    : '<span class="badge-flag-unreviewed">Unread</span>';

  document.getElementById('toggle-read-btn').textContent = viewingTicket.is_read ? 'Mark as Unread' : 'Mark as Read';

  // Auto-mark as read when viewing
  if (!viewingTicket.is_read) {
    toggleTicketRead();
  }
}

async function toggleTicketRead() {
  if (!viewingTicket) return;
  const newReadState = !viewingTicket.is_read;
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${SUPPORT_TABLE}?id=eq.${viewingTicket.id}`,
      {
        method: 'PATCH',
        headers: headers(),
        body: JSON.stringify({ is_read: newReadState }),
      }
    );
    if (!res.ok) throw new Error(`Update failed: ${res.status}`);
    viewingTicket.is_read = newReadState;

    const readBadge = document.getElementById('ticket-read-badge');
    readBadge.innerHTML = newReadState
      ? '<span class="badge">Read</span>'
      : '<span class="badge-flag-unreviewed">Unread</span>';
    document.getElementById('toggle-read-btn').textContent = newReadState ? 'Mark as Unread' : 'Mark as Read';
  } catch (e) {
    toast(e.message, 'error');
  }
}

async function deleteTicket() {
  if (!viewingTicket) return;
  if (!confirm('Delete this ticket permanently?')) return;
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/${SUPPORT_TABLE}?id=eq.${viewingTicket.id}`,
      { method: 'DELETE', headers: headers() }
    );
    if (!res.ok) throw new Error(`Delete failed: ${res.status}`);
    supportTickets = supportTickets.filter(t => t.id !== viewingTicket.id);
    viewingTicket = null;
    document.getElementById('support-detail').classList.add('hidden');
    document.getElementById('support-view').classList.remove('hidden');
    renderSupportTickets();
    toast('Ticket deleted.', 'success');
  } catch (e) {
    toast(e.message, 'error');
  }
}

function replyToTicket() {
  if (!viewingTicket || !viewingTicket.email) return;
  const subject = encodeURIComponent(`Re: ${REASON_LABELS[viewingTicket.reason] || 'Support'} - Memorezar`);
  window.open(`mailto:${viewingTicket.email}?subject=${subject}`, '_blank');
}

// ── Support Event Listeners ──

document.getElementById('support-back-btn').addEventListener('click', () => {
  document.getElementById('support-detail').classList.add('hidden');
  document.getElementById('support-view').classList.remove('hidden');
  renderSupportTickets();
});

document.getElementById('toggle-read-btn').addEventListener('click', toggleTicketRead);
document.getElementById('delete-ticket-btn').addEventListener('click', deleteTicket);
document.getElementById('reply-ticket-btn').addEventListener('click', replyToTicket);

document.getElementById('support-search').addEventListener('input', (e) => {
  supportSearchQuery = e.target.value;
  renderSupportTickets();
});

document.querySelectorAll('[data-support-filter]').forEach(btn => {
  btn.addEventListener('click', () => {
    supportFilter = btn.dataset.supportFilter;
    document.querySelectorAll('[data-support-filter]').forEach(b =>
      b.classList.toggle('active', b.dataset.supportFilter === supportFilter)
    );
    renderSupportTickets();
  });
});

document.getElementById('support-reason-filter').addEventListener('change', (e) => {
  supportReasonFilter = e.target.value;
  renderSupportTickets();
});

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
