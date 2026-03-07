# backend/reset_db.py
import database
import models

def reset_database():
    print("Purging all tables...")
    models.Base.metadata.drop_all(bind=database.engine)
    print("Recreating clean schema...")
    models.Base.metadata.create_all(bind=database.engine)
    print("Database reset complete.")

if __name__ == "__main__":
    reset_database()