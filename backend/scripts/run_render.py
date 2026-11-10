"""Start the API behind Render's edge without migrations or demo seeding."""
import os
import sys


def main():
    # Render terminates TLS and exposes only its edge publicly. Until explicit
    # proxy trust is configured, do not trust client-supplied forwarding headers.
    os.execv(sys.executable, [sys.executable, '-m', 'uvicorn', 'app.main:app',
        '--host', '0.0.0.0', '--port', os.environ.get('PORT', '10000'),
        '--no-proxy-headers', '--no-access-log', '--limit-concurrency', '16'])


if __name__ == '__main__':
    main()
