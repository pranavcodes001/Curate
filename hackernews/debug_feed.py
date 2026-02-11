import sqlite3

def check_db():
    try:
        conn = sqlite3.connect('dev.db')
        cursor = conn.cursor()
        
        print("--- Interests ---")
        cursor.execute("SELECT id, name, group_name FROM interests")
        interests = cursor.fetchall()
        for i in interests:
            print(i)
            
        print("\n--- User Interests ---")
        cursor.execute("SELECT user_id, interest_id FROM user_interests")
        uis = cursor.fetchall()
        for ui in uis:
            print(ui)
            
        print("\n--- Interest Stories Counts ---")
        cursor.execute("SELECT interest_id, count(*) FROM interest_stories GROUP BY interest_id")
        counts = cursor.fetchall()
        for c in counts:
            print(f"Interest {c[0]}: {c[1]} stories")
            
        print("\n--- Users ---")
        cursor.execute("SELECT id, email FROM users")
        users = cursor.fetchall()
        for u in users:
            print(u)
            
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_db()
