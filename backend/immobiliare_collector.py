import asyncio
from playwright.async_api import async_playwright
from playwright_stealth import stealth_async
import json
import time
import random

async def scrape_immobiliare():
    async with async_playwright() as p:
        # Launch browser with additional options to avoid detection
        browser = await p.chromium.launch(
            headless=True,
            args=[
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu'
            ]
        )

        # Set random user agent
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        ]

        context = await browser.new_context(
            user_agent=random.choice(user_agents),
            viewport={'width': 1280, 'height': 720}
        )
        page = await context.new_page()

        # Apply stealth to avoid detection
        await stealth_async(page)

        # Add random delay to simulate human behavior
        await asyncio.sleep(random.uniform(1, 3))

        try:
            # Navigate to Immobiliare.it
            await page.goto("https://www.immobiliare.it/")

            # Wait for the page to load
            await page.wait_for_load_state('networkidle')

            # Example: Search for properties in Milan
            await page.fill('input[name="q"]', 'Milano')
            await page.click('button[type="submit"]')

            # Wait for results
            await page.wait_for_selector('.listing-item')

            # Extract property data
            properties = await page.evaluate('''
                () => {
                    const items = document.querySelectorAll('.listing-item');
                    return Array.from(items).map(item => ({
                        title: item.querySelector('.listing-item_title')?.textContent?.trim(),
                        price: item.querySelector('.listing-item_price')?.textContent?.trim(),
                        location: item.querySelector('.listing-item_address')?.textContent?.trim(),
                        url: item.querySelector('a')?.href
                    }));
                }
            ''')

            # Save to JSON
            with open('immobiliare_data.json', 'w', encoding='utf-8') as f:
                json.dump(properties, f, ensure_ascii=False, indent=2)

            print(f"Scraped {len(properties)} properties")

        except Exception as e:
            print(f"Error: {e}")

        finally:
            await browser.close()

if __name__ == "__main__":
    asyncio.run(scrape_immobiliare())
