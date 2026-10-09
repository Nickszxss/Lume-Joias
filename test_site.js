const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  const consoleLogs = [];
  const pageErrors = [];
  page.on('console', msg => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', err => pageErrors.push(err.message));

  console.log('Navigating to https://nickszxss.github.io/Lume-Joias/ ...');
  await page.goto('https://nickszxss.github.io/Lume-Joias/', { waitUntil: 'networkidle' });

  console.log('Title:', await page.title());

  // Take screenshot of login page
  await page.screenshot({ path: 'login_page.png' });

  // Test Login with different users
  console.log('\n--- Console Logs on Load ---');
  consoleLogs.forEach(log => console.log(log));
  if (pageErrors.length > 0) {
    console.log('\n--- Page Errors on Load ---');
    pageErrors.forEach(err => console.log(err));
  }

  await browser.close();
})();
