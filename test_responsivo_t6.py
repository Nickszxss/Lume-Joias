import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING RESPONSIVE DESIGN TESTS (TASK 6) ===")
    os.makedirs("/tmp/t6_screenshots", exist_ok=True)

    viewports = [
        {"name": "375px_smartphone", "width": 375, "height": 667},
        {"name": "390px_smartphone", "width": 390, "height": 844},
        {"name": "768px_tablet_portrait", "width": 768, "height": 1024},
        {"name": "1024px_tablet_landscape", "width": 1024, "height": 768},
        {"name": "1366px_desktop", "width": 1366, "height": 768}
    ]

    async with async_playwright() as p:
        browser = await p.chromium.launch()

        for vp in viewports:
            print(f"Testing viewport: {vp['name']} ({vp['width']}x{vp['height']})")
            context = await browser.new_context(viewport={"width": vp["width"], "height": vp["height"]})
            page = await context.new_page()
            await page.goto("http://localhost:8080/index.html")

            # Login as Robson (Manager)
            await page.fill("#login-nome", "Robson")
            await page.fill("#login-email", "robson.grt@empresa.com")
            await page.fill("#login-senha", "etec2026@DS")
            await page.click("button:has-text('Entrar')")
            await page.wait_for_selector("#app.active", timeout=10000)
            await page.wait_for_timeout(1000)

            # 1. Screenshot Dashboard Light Mode
            await page.screenshot(path=f"/tmp/t6_screenshots/dash_{vp['name']}_light.png")

            # 2. Go to Produtos Table
            await page.click("a[data-page='produtos']")
            await page.wait_for_selector("#page-produtos.active", timeout=5000)
            await page.wait_for_timeout(500)
            await page.screenshot(path=f"/tmp/t6_screenshots/produtos_{vp['name']}_light.png")

            # 3. Toggle Dark Mode
            await page.click("#theme-toggle")
            await page.wait_for_timeout(500)
            await page.screenshot(path=f"/tmp/t6_screenshots/produtos_{vp['name']}_dark.png")

            # 4. Open Modal for Modal Scroll test
            await page.click("button:has-text('+ Novo Produto')")
            await page.wait_for_selector("#modal-produto", timeout=5000)
            await page.wait_for_timeout(500)
            await page.screenshot(path=f"/tmp/t6_screenshots/modal_{vp['name']}_dark.png")

            await context.close()

        await browser.close()
    print("=== ALL RESPONSIVE TESTS & SCREENSHOTS CAPTURED SUCCESSFULLY! ===")

asyncio.run(run())
