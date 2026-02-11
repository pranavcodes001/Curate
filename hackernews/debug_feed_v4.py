import sqlite3

def check_db():
    try:
        conn = sqlite3.connect('dev.db')
        cursor = conn.cursor()
        
        print("\n--- Orphaned Interest Stories (no match in 'stories' table) ---")
        cursor.execute("SELECT ist.interest_id, ist.story_hn_id FROM interest_stories ist LEFT JOIN stories s ON ist.story_hn_id = s.hn_id WHERE s.hn_id IS NULL LIMIT 20")
        orphans = cursor.fetchall()
        print(f"Orphaned count (sampled): {len(orphans)}")
        for o in orphans:
            print(o)
            
        print("\n--- Valid Interest Stories Samples ---")
        cursor.execute("SELECT i.name, s.title FROM interest_stories ist JOIN interests i ON ist.interest_id = i.id JOIN stories s ON ist.story_hn_id = s.hn_id LIMIT 10")
        valid = cursor.fetchall()
        for v in valid:
            print(v)
            
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_db()
