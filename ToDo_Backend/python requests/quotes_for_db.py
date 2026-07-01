import datetime
import requests
import psycopg2

DB_SETTINGS = {
    "host": "localhost",
    "port": 5432,
    "database": "todo_db",
    "user": "postgres",
    "password": "root"
}

START_DATE = datetime.date(2026, 1, 1)
DAYS_COUNT = 365

def fetch_365_dummy_quotes():
    # Запрашиваем сразу 365 цитат за один раз!
    url = f"https://dummyjson.com/quotes?limit={DAYS_COUNT}"
    print(f"Запрашиваем данные с DummyJSON (требуется количество: {DAYS_COUNT})...")
    
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            raw_quotes = data.get("quotes", [])
            
            quotes_list = []
            for item in raw_quotes:
                text = item.get("quote", "").strip().upper() # ToUpper для C#
                author = item.get("author", "Unknown").strip()
                if text:
                    quotes_list.append({"text": text, "author": author})
            
            print(f"Успешно получено {len(quotes_list)} уникальных цитат.")
            return quotes_list
        else:
            print(f"Ошибка API: Статус {response.status_code}")
            return []
    except Exception as e:
        print(f"Ошибка сети: {e}")
        return []

def insert_to_postgres(quotes):
    if not quotes or len(quotes) < DAYS_COUNT:
        print("Ошибка: Недостаточно цитат для заполнения всего года!")
        return

    print("\nПодключаемся к PostgreSQL для записи...")
    try:
        conn = psycopg2.connect(**DB_SETTINGS)
        cursor = conn.cursor()
        
        # Очищаем таблицу
        cursor.execute('DELETE FROM "Quotes";')
        
        current_date = START_DATE
        for q in quotes:
            query = '''
                INSERT INTO "Quotes" ("Text", "Author", "TargetDate") 
                VALUES (%s, %s, %s);
            '''
            cursor.execute(query, (q["text"], q["author"], current_date))
            current_date += datetime.timedelta(days=1)
            
        conn.commit()
        print(f"🔥 Идеально! База успешно заполнена на 365 абсолютно РАЗНЫХ цитат.")
        print(f"Период действия: с {START_DATE} по {current_date - datetime.timedelta(days=1)}")
        
    except Exception as e:
        print(f"Ошибка БД: {e}")
    finally:
        if 'conn' in locals():
            cursor.close()
            conn.close()

if __name__ == "__main__":
    quotes_pool = fetch_365_dummy_quotes()
    insert_to_postgres(quotes_pool)