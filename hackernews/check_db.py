import sqlite3

def check_db():
    try:
        conn = sqlite3.connect('dev.db')
        cursor = conn.cursor()
        
        cursor.execute("SELECT count(*) FROM top_stories")
        count = cursor.fetchone()[0]
        print(f"Top stories count: {count}")
        
        cursor.execute("SELECT count(*) FROM stories")
        count_stories = cursor.fetchone()[0]
        print(f"Total stories count: {count_stories}")
        
        cursor.execute("SELECT hn_id FROM top_stories LIMIT 5")
        ids = cursor.fetchall()
        print(f"First 5 top ids: {ids}")
        
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_db()
