import psycopg2
DB_SETTINGS = {
    "host": "localhost",
    "port": 5432,
    "database": "todo_db",
    "user": "postgres",
    "password": "root"
}



def clear_identity_users():
    print("\nПодключаемся к PostgreSQL для очистки пользователей...")
    try:
        conn = psycopg2.connect(**DB_SETTINGS)
        cursor = conn.cursor()
        
        # Удаляем каскадом — быстро и чисто
        cursor.execute('TRUNCATE TABLE "AspNetUsers" CASCADE;')
        
        conn.commit()
        print("🔥 Все таблицы AspNetUsers успешно полностью очищены!")
        
    except Exception as e:
        print(f"Ошибка при очистке БД: {e}")
    finally:
        if 'conn' in locals():
            cursor.close()
            conn.close()

# Вызов в самом низу файла:
if __name__ == "__main__":
    clear_identity_users()