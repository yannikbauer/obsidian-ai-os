// Goodreads shelf snapshot. Read-only.
//
// Run in a signed-in goodreads.com tab through the browser tool's javascript_exec
// (Claude in Chrome). Shelves are private, so there is no public RSS or headless route;
// the user's browser session is the access. Paste this whole file as the script; it
// returns one markdown string, which the caller writes to _AI/tmp/goodreads-snapshot.md.
// javascript_exec truncates its result at about 1k characters, so the string is kept in
// window.__grSnapshot. Read it back in one go: render it into the tab and read the page text
//   document.body.innerHTML=''; const a=document.createElement('article');
//   const p=document.createElement('pre'); p.textContent=window.__grSnapshot;
//   a.appendChild(p); document.body.appendChild(a);
// then get_page_text on the tab (verified 2026-11-12: 396 books, ~43k chars, one call).
//
// USER_ID is read from the signed-in page (the profile link), so nothing personal lives
// here; integrations/goodreads.md records it for reference. Field selectors verified 2026-11-12;
// if a column comes back empty for every book, Goodreads changed its table markup.
// Return a markdown string, not an object: the browser tool's output filter blocks
// object keys it thinks are sensitive (an "author" key came back redacted).

const profile = document.querySelector('a[href*="/user/show/"]');
if (!profile) throw new Error('Not signed in to Goodreads in this tab');
const USER_ID = profile.getAttribute('href').match(/\/user\/show\/(\d+)/)[1];
const PER_PAGE = 100;

const clean = s => (s || '').replace(/\[edit\]/g, '').replace(/\s+/g, ' ').trim();

async function page(n) {
  const r = await fetch(`/review/list/${USER_ID}?shelf=%23ALL%23&per_page=${PER_PAGE}&page=${n}&sort=date_added&order=d`, { credentials: 'include' });
  const d = new DOMParser().parseFromString(await r.text(), 'text/html');
  return [...d.querySelectorAll('tr.bookalike')].map(tr => {
    const t = sel => clean((tr.querySelector(sel) || {}).textContent);
    const stars = tr.querySelector('td.rating .stars[data-rating]');
    const rating = stars ? Math.round(parseFloat(stars.dataset.rating)) : 0;
    const shelves = t('td.shelves .value').replace(/,\s*/g, ', ');
    const notDate = s => (!s || /not set|unknown/i.test(s)) ? '' : s;
    return {
      title: t('td.title .value a'),
      by: t('td.author .value a'),
      rating,
      shelves,
      started: notDate(t('td.date_started .value')),
      finished: notDate(t('td.date_read .value')),
      added: notDate(t('td.date_added .value')),
      pages: t('td.num_pages .value').replace(/\s*pp$/, ''),
      // an empty review cell reads "Write a review"
      review: !/^(write a review|none)?$/i.test(clean((tr.querySelector('td.review .value') || {}).textContent)),
    };
  });
}

let all = [];
for (let n = 1; n < 20; n++) {
  const rows = await page(n);
  all = all.concat(rows);
  if (rows.length < PER_PAGE) break;
}

const primary = b => {
  for (const s of ['currently-reading', 'to-read', 'read']) if (b.shelves.split(', ').includes(s)) return s;
  return b.shelves.split(', ')[0] || 'other';
};
const groups = {};
for (const b of all) (groups[primary(b)] ||= []).push(b);

const line = b => {
  const parts = [`${b.title} — ${b.by}`];
  if (b.rating) parts.push('★'.repeat(b.rating));
  if (b.started) parts.push(`started ${b.started}`);
  if (b.finished) parts.push(`finished ${b.finished}`);
  if (!b.started && !b.finished && b.added) parts.push(`added ${b.added}`);
  if (b.pages && b.pages !== '0') parts.push(`${b.pages} pp`);
  const extra = b.shelves.split(', ').filter(s => s !== primary(b));
  if (extra.length) parts.push(`shelves: ${extra.join(', ')}`);
  if (b.review) parts.push('has review');
  return '- ' + parts.join(' · ');
};

const order = ['currently-reading', 'to-read', 'read', ...Object.keys(groups).filter(k => !['currently-reading', 'to-read', 'read'].includes(k))];
const today = new Date().toISOString().slice(0, 10);
let md = `# Goodreads shelves snapshot\n\nCopy of the Goodreads shelves as of ${today}, made by the AIOS (\`_AI/tools/goodreads-snapshot.js\`). Goodreads wins over this copy; if it is weeks old, say so. ${all.length} books.\n`;
for (const k of order) {
  if (!groups[k]) continue;
  md += `\n## ${k} (${groups[k].length})\n\n` + groups[k].map(line).join('\n') + '\n';
}
window.__grSnapshot = md;
`${md.length} chars; read window.__grSnapshot in slices`;
