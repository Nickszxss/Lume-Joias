from playwright.sync_api import sync_playwright

def run_cuj(page):
    page.goto("http://localhost:8080/index.html")
    page.wait_for_timeout(1000)

    # Fill login form
    page.fill("#login-email", "robson.grt@empresa.com")
    page.fill("#login-senha", "etec2026@DS")
    page.wait_for_timeout(500)
    page.click("button[onclick='fazerLogin()']")
    page.wait_for_timeout(1000)

    # Navigate to produtos
    page.click("a[data-page='produtos']")
    page.wait_for_timeout(1000)

    # Open modal
    page.click("button[onclick='abrirModalProduto()']")
    page.wait_for_timeout(1000)

    # Take screenshot
    page.screenshot(path="/home/jules/verification/screenshots/verification.png")
    page.wait_for_timeout(1000)

    # Close modal
    page.click("#modal-produto button.btn-secondary")
    page.wait_for_timeout(1000)

if __name__ == "__main__":
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            record_video_dir="/home/jules/verification/videos"
        )
        page = context.new_page()
        try:
            run_cuj(page)
        finally:
            context.close()
            browser.close()
