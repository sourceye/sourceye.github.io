import functions_framework
import requests
import os
import re
from google.cloud import error_reporting

NOTION_DB_ID = os.environ.get("NOTION_DB_ID")
NOTION_QUERY = f"https://api.notion.com/v1/databases/{NOTION_DB_ID}/query"
NOTION_ADD = f"https://api.notion.com/v1/pages"
NOTION_API_KEY = os.environ.get("NOTION_API_KEY")
HEADERS = {
    "accept": "application/json",
    "Notion-Version": "2022-06-28",
    "content-type": "application/json",
    "Authorization": f"Bearer {NOTION_API_KEY}",
}
EMAIL_VALIDATOR = r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b"


def add_email(email: str) -> None:
    data = {
        "parent": {"database_id": NOTION_DB_ID},
        "properties": {
            "Name": {"title": [{"text": {"content": f"Interested party at {email}"}}]},
            "Email": {"email": email},
        },
    }
    requests.post(NOTION_ADD, json=data, headers=HEADERS)


def email_exists(email: str) -> bool:
    payload = {
        "page_size": 100,
        "filter": {"property": "Email", "email": {"equals": email}},
    }
    response = requests.post(NOTION_QUERY, json=payload, headers=HEADERS)
    if "results" not in response.json():
        raise ValueError(response.json())
    return len(response.json()["results"]) != 0


def email_valid(email: str) -> bool:
    return re.fullmatch(EMAIL_VALIDATOR, email)


def collect_email(email: str) -> None:
    """Collects an email

    Will validate the email and only add it when it does not exists yet in the notion database

    Raises:
        ValueError: If the email is invalid or it already exists
    """
    # Check if the email is valid
    if not email_valid(email):
        raise ValueError("Invalid email")

    # Check if the email was not yet added
    if email_exists(email):
        raise ValueError("Email already exists")

    # Add the email
    add_email(email)


@functions_framework.http
def handle_email_collection(request):
    # Set CORS headers for the preflight request
    if request.method == "OPTIONS":
        # Allows GET requests from any origin with the Content-Type
        # header and caches preflight response for an 3600s
        headers = {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "3600",
        }

        return ("", 204, headers)

    # Set CORS headers for the main request
    headers = {"Access-Control-Allow-Origin": "*"}

    client = error_reporting.Client()
    try:
        collect_email(request.get_json()["email"])
    except ValueError:
        client.report_exception()
        return ("REJECTED", 400, headers)
    return ("OK", 200, headers)


if __name__ == "__main__":
    collect_email("theo@sourceye.com")
