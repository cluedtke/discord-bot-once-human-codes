# import discord
# from discord.ext import commands
import os
import requests
import boto3
from bs4 import BeautifulSoup

URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=3286138212"
WEBHOOK_URL = os.environ["DISCORD_WEBHOOK"]
S3_BUCKET = os.environ["S3_BUCKET"]
S3_KEY = os.environ["S3_KEY"]

s3 = boto3.client("s3")


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

        # Compare codes with the ones stored in S3
        obj = s3.get_object(Bucket=S3_BUCKET, Key=S3_KEY)
        codes_in_s3 = obj["Body"].read().decode("utf-8")

        if msg == codes_in_s3:
            msg = "No new codes available."
        else:
            # Update the S3 object with the new codes
            s3.put_object(Bucket=S3_BUCKET, Key=S3_KEY, Body=msg)

            # Parse added and removed codes
            redeem_codes = msg.split("\n")[1:]
            added_codes = set(redeem_codes) - set(codes_in_s3.split("\n")[1:])
            removed_codes = set(codes_in_s3.split("\n")[1:]) - set(redeem_codes)
            removed_codes = [code for code in removed_codes if code.strip()] # Remove empty strings
            msg = f"**Codes have changed!\n{last_updated}**"
            if added_codes:
                msg += f"\nAdded:\n{'\n'.join([f"+ {code}" for code in added_codes])}"
            if removed_codes:
                msg += f"\nRemoved:\n{'\n'.join([f"\- {code}" for code in removed_codes])}"

        # Print out the redeem codes
        requests.post(WEBHOOK_URL, json={"content": msg}, timeout=5)
    else:
        print(f"Failed to retrieve the webpage. Status code: {response.status_code}")


if __name__ == "__main__":
    lambda_handler(None, None)
