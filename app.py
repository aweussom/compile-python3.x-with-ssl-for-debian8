"""Tiny demo application compiled by build.sh."""
import argparse
import datetime as dt


def main() -> None:
    parser = argparse.ArgumentParser(description="Hello from a PyInstaller-built binary")
    parser.add_argument("--name", default="world", help="Name to greet")
    args = parser.parse_args()
    now = dt.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"[{now}] Hello, {args.name}! This binary was built inside Docker.")


if __name__ == "__main__":
    main()
