import asyncio
from playwright.async_api import async_playwright

async def test_login_flow():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        print("--- Navigating to Lume Joias ---")
        await page.goto("https://nickszxss.github.io/Lume-Joias/", wait_until="networkidle")

        # Test login with Robson
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")

        await page.wait_for_timeout(1000)

        # Check state after login
        state = await page.evaluate("""() => {
            return {
                appActive: document.getElementById('app').classList.contains('active'),
                loginDisplay: document.getElementById('login-screen').style.display,
                userGlobal: window.usuario || null,
                localStorageUser: localStorage.getItem('lume_usuario'),
                toastText: document.getElementById('toast')?.innerText
            };
        }""")

        print("State after login attempt:", state)

        await browser.close()

asyncio.run(test_login_flow())
