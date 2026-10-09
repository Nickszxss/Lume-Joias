import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    os.makedirs("/tmp/responsive_screenshots", exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        viewports = [
            {"width": 360, "height": 740, "name": "360px"},
            {"width": 375, "height": 667, "name": "375px"},
            {"width": 390, "height": 844, "name": "390px"},
            {"width": 400, "height": 800, "name": "400px"},
            {"width": 768, "height": 1024, "name": "768px"},
            {"width": 1366, "height": 768, "name": "1366px"},
        ]

        for vp in viewports:
            context = await browser.new_context(viewport={"width": vp["width"], "height": vp["height"]})
            page = await context.new_page()
            await page.goto("http://localhost:8080/index.html")

            # Login as Robson
            await page.fill("#login-email", "robson.grt@empresa.com")
            await page.fill("#login-senha", "etec2026@DS")
            await page.click("button:has-text('Entrar')")
            await page.wait_for_selector("#app.active", timeout=5000)
            await page.wait_for_timeout(1000)

            # Capture Light Mode
            await page.screenshot(path=f"/tmp/responsive_screenshots/dash_{vp['name']}_light.png")

            # Go to Produtos (Table)
            await page.click("a[data-page='produtos']")
            await page.wait_for_timeout(500)
            await page.screenshot(path=f"/tmp/responsive_screenshots/produtos_{vp['name']}_light.png")

            # Toggle Dark Mode
            await page.click("#theme-toggle")
            await page.wait_for_timeout(500)
            await page.screenshot(path=f"/tmp/responsive_screenshots/produtos_{vp['name']}_dark.png")

            await context.close()

        await browser.close()
    print("ALL RESPONSIVE LIGHT AND DARK SCREENSHOTS CAPTURED SUCCESSFULLY!")

asyncio.run(run())
