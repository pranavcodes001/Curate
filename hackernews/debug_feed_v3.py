import sqlite3

def check_db():
    try:
        conn = sqlite3.connect('dev.db')
        cursor = conn.cursor()
        
        print("--- Interests + Keywords ---")
        cursor.execute("SELECT id, name, keywords FROM interests")
        interests = cursor.fetchall()
        for i in interests:
            print(i)
            
        print("\n--- Interest Stories Sample ---")
        cursor.execute("SELECT i.name, s.title FROM interest_stories ist JOIN interests i ON ist.interest_id = i.id JOIN stories s ON ist.story_hn_id = s.hn_id LIMIT 10")
        sample = cursor.fetchall()
        for s in sample:
            print(s)
            
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_db()
