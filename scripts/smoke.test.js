// Smoke test ClassCraft SMP: muat semua halaman & gagalkan jika ada
// console error / page error. Dijalankan di CI (GitHub Actions),
// butuh playwright (di-install on-the-fly di runner).
const { chromium } = require('playwright');

(async () => {
  const base = 'http://127.0.0.1:5599';
  const pages = [
    'index.html', 'login.html',
    'guru-dashboard.html', 'guru-rpp.html', 'guru-absensi.html', 'guru-jurnal.html', 'guru-soal.html',
    'admin-profil.html', 'admin-guru.html', 'admin-kelas.html', 'admin-backup.html'
  ];

  const browser = await chromium.launch();
  const problems = [];

  for (const p of pages) {
    const page = await browser.newPage();
    page.on('console', (msg) => {
      if (msg.type() === 'error') problems.push(p + ': [console] ' + msg.text());
    });
    page.on('pageerror', (err) => problems.push(p + ': [pageerror] ' + err.message));
    try {
      await page.goto(base + '/' + p, { waitUntil: 'load', timeout: 20000 });
      await page.waitForTimeout(800);
    } catch (e) {
      problems.push(p + ': navigation failed -> ' + e.message);
    }
    await page.close();
  }

  await browser.close();

  if (problems.length) {
    console.error('SMOKE TEST GAGAL:\n' + problems.join('\n'));
    process.exit(1);
  }
  console.log('Smoke test OK — ' + pages.length + ' halaman dimuat tanpa console/page error.');
})();
