#!/usr/bin/env python3
"""
Run this ONCE before starting the server for the first time.
Creates the 'sos_guardian' database and all tables.

Usage:
    python setup_db.py
    python setup_db.py --user postgres --password yourpassword
"""
import argparse
import os
import sys

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--user",     default="postgres")
    p.add_argument("--password", default="password")
    p.add_argument("--host",     default="localhost")
    p.add_argument("--port",     default="5432")
    p.add_argument("--dbname",   default="sos_guardian")
    args = p.parse_args()

    try:
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
    except ImportError:
        print("ERROR: psycopg2 not installed. Run: pip install psycopg2-binary")
        sys.exit(1)

    # Step 1: Connect to default 'postgres' DB to create our DB
    print(f"Connecting to PostgreSQL at {args.host}:{args.port} as {args.user}…")
    try:
        conn = psycopg2.connect(
            host=args.host, port=args.port,
            user=args.user, password=args.password,
            dbname="postgres",
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()

        # Check if DB exists
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (args.dbname,))
        if cur.fetchone():
            print(f"  Database '{args.dbname}' already exists — skipping creation.")
        else:
            cur.execute(f'CREATE DATABASE "{args.dbname}"')
            print(f"  Database '{args.dbname}' created.")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"ERROR connecting to PostgreSQL: {e}")
        print("\nTroubleshooting:")
        print("  1. Make sure PostgreSQL is running")
        print("  2. Check your username/password")
        print("  3. Try: python setup_db.py --user postgres --password yourpassword")
        sys.exit(1)

    # Step 2: Update .env with the correct URL
    db_url = f"postgresql://{args.user}:{args.password}@{args.host}:{args.port}/{args.dbname}"
    env_path = os.path.join(os.path.dirname(__file__), ".env")

    with open(env_path, "w") as f:
        f.write(f"DATABASE_URL={db_url}\n")
        f.write("HOST=0.0.0.0\n")
        f.write("PORT=8000\n")
    print(f"  .env updated with DATABASE_URL.")

    # Step 3: Create all tables via SQLAlchemy
    # Set env so database.py picks it up
    os.environ["DATABASE_URL"] = db_url
    sys.path.insert(0, os.path.dirname(__file__))

    try:
        import database
        import models
        models.Base.metadata.create_all(bind=database.engine)
        print("  All tables created successfully.")
    except Exception as e:
        print(f"ERROR creating tables: {e}")
        sys.exit(1)

    print("\n✅  Setup complete!")
    print(f"   Database : {args.dbname}")
    print(f"   URL      : {db_url}")
    print("\n   Start the server with:")
    print("       python main.py")
    print("   or  uvicorn main:app --host 0.0.0.0 --port 8000 --reload\n")


if __name__ == "__main__":
    main()
