import requests
import traceback
from airflow.hooks.base import BaseHook
import time
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
from datetime import datetime, timedelta

GCHAT_CONNECTION = "my_gchat_webhook"
ALERT_COOLDOWN_SECONDS = 600  # 10 minutes

def create_retry_session(
    retries=3,
    backoff_factor=0.5,
    status_forcelist=(429, 500, 502, 503, 504),
):
    """Create a requests session with retry logic"""
    session = requests.Session()
    retry = Retry(
        total=retries,
        read=retries,
        connect=retries,
        backoff_factor=backoff_factor,
        status_forcelist=status_forcelist,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    return session

def _make_http_request(body, webhook_url, max_retries=3):
    """
    Sends an HTTP POST request with retry logic.
    """
    session = create_retry_session(retries=max_retries)

    try:
        response = session.post(
            url=webhook_url,
            json=body,
            headers={"Content-type": "application/json"},
            timeout=10  # Added timeout
        )
        print(f"Response status: {response.status_code}, Success: {response.ok}")

        if response.status_code == 429:
            # If we still hit rate limit after retries, log it clearly
            print(f"Rate limit hit. Response: {response.text}")
            # Try one last time with a longer delay
            time.sleep(2)
            response = session.post(
                url=webhook_url,
                json=body,
                headers={"Content-type": "application/json"},
                timeout=10
            )

        return response.ok
    except Exception as e:
        print(f"Error sending message to GChat: {str(e)}")
        return False
    finally:
        session.close()

def _get_webhook_url(connection_id: str):
    """
    Retrieves the webhook URL from Airflow connection.
    """
    conn = BaseHook.get_connection(connection_id)
    return conn.host

last_alert_time = None

def task_fail_alert(context):
    """
    Sends an alert to Google Chat in case of task failure.
    """
    global last_alert_time

    try:
        run_id = str(context.get("task_instance").dag_id)+"-"+str(context.get("task_instance").run_id).replace(
            "+", "-").replace(":", "-")

        print("task_fail_alert()")
        exception = context.get("exception")
        formatted_exception = str(exception)
        try:
            tb = None if type(exception) == str else exception.__traceback__
            formatted_exception = "".join(
                traceback.format_exception(etype=type(
                    exception), value=exception, tb=tb)
            )
        except:
            pass

        # Check if we need to apply a cool-down period
        current_time = datetime.now()
        if last_alert_time and (current_time - last_alert_time) < timedelta(seconds=ALERT_COOLDOWN_SECONDS):
            print(f"Skipping alert due to cool-down period. Last alert was {(current_time - last_alert_time).seconds} seconds ago.")
            return

        # Simplified message to reduce payload size
        body = {
            'cardsV2': [{
                'cardId': 'createCardMessage',
                'card': {
                    'header': {
                        'title': f"❌ {context.get('task_instance').task_id} failed",
                        'subtitle': context.get("task_instance").dag_id,
                    },
                    'sections': [
                        {
                            'widgets': [
                                {
                                    "textParagraph": {
                                        "text": (
                                            f"<b>Time:</b> {context.get('logical_date')}\n"
                                            f"<b>Duration:</b> {context.get('task_instance').duration}s\n"
                                            f"<b>Error:</b> {str(exception)[:150]}"
                                        )
                                    }
                                },
                                {
                                    'buttonList': {
                                        'buttons': [
                                            {
                                                'text': 'View Logs',
                                                'onClick': {
                                                    'openLink': {
                                                        'url': context.get("task_instance").log_url
                                                    }
                                                }
                                            }
                                        ]
                                    }
                                }
                            ]
                        }
                    ]
                }
            }]
        }

        webhook_url = _get_webhook_url(GCHAT_CONNECTION)
        thread_url = f"{webhook_url}&threadKey={run_id}&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD"

        print("sending alert card")
        if _make_http_request(body, thread_url):
            # Only send exception details if main message succeeded
            print("sending exception as a thread")
            exception_body = {
                "text": f"```{formatted_exception[:1500]}```"  # Limit exception length
            }
            _make_http_request(exception_body, thread_url)

            # Update the last alert time
            last_alert_time = current_time
    except Exception as e:
        print(f"Error in task_fail_alert: {str(e)}")
