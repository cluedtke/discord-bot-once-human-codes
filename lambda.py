# import discord
# from discord.ext import commands
import os
import requests
from bs4 import BeautifulSoup

# URL of the page to be parsed
URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=3286138212"
WEBHOOK_URL = os.environ["DISCORD_WEBHOOK"]


def lambda_handler(event, context):
    # Send a GET request to the URL
    response = requests.get(URL, timeout=5)

    # Check if the request was successful
    if response.status_code == 200:
        # Parse the content of the page
        soup = BeautifulSoup(response.content, "html.parser")

        # Find the table containing the redeem codes
        redeem_codes_table = soup.find("div", {"class": "bb_table"})

        # Extract all rows from the table (ignore first header row)
        redeem_codes_rows = redeem_codes_table.find_all(
            "div", {"class": "bb_table_tr"}
        )[1:]

        # The first div in each row contains the redeem code
        redeem_codes = [row.find("div").text.strip() for row in redeem_codes_rows]

        # Find last updated element
        last_updated = soup.find(
            lambda tag: tag.name == "i" and "This list was updated" in tag.text
        ).text.strip()

        msg = f"**{last_updated}**"
        msg += f"\n{'\n'.join(redeem_codes)}"

        # Print out the redeem codes
        requests.post(WEBHOOK_URL, json={"content": msg}, timeout=5)
    else:
        print(f"Failed to retrieve the webpage. Status code: {response.status_code}")


if __name__ == "__main__":
    lambda_handler(None, None)
