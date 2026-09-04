use rusqlite::{Connection, OptionalExtension, params};
use std::{fs, sync::Mutex};
use tauri::Manager;

const DATABASE_FILE: &str = "fluxday.sqlite3";
const SCHEMA_VERSION: i64 = 1;
const MIGRATION_V1: &str = r#"
CREATE TABLE IF NOT EXISTS app_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  schema_version INTEGER NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"#;

struct DatabaseState(Mutex<Connection>);

fn migrate(connection: &mut Connection) -> rusqlite::Result<()> {
    let version: i64 = connection.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    if version < 1 {
        let transaction = connection.transaction()?;
        transaction.execute_batch(MIGRATION_V1)?;
        transaction.pragma_update(None, "user_version", SCHEMA_VERSION)?;
        transaction.commit()?;
    }
    Ok(())
}

fn write_snapshot(connection: &mut Connection, payload: &str) -> rusqlite::Result<()> {
    let transaction = connection.transaction()?;
    transaction.execute(
        "INSERT INTO app_state (id, schema_version, payload, updated_at)
         VALUES (1, ?1, ?2, CURRENT_TIMESTAMP)
         ON CONFLICT(id) DO UPDATE SET
           schema_version = excluded.schema_version,
           payload = excluded.payload,
           updated_at = CURRENT_TIMESTAMP",
        params![SCHEMA_VERSION, payload],
    )?;
    transaction.commit()
}

#[tauri::command]
fn load_snapshot(database: tauri::State<'_, DatabaseState>) -> Result<Option<String>, String> {
    let connection = database.0.lock().map_err(|error| error.to_string())?;
    connection
        .query_row("SELECT payload FROM app_state WHERE id = 1", [], |row| {
            row.get(0)
        })
        .optional()
        .map_err(|error| error.to_string())
}

#[tauri::command]
fn save_snapshot(payload: String, database: tauri::State<'_, DatabaseState>) -> Result<(), String> {
    serde_json::from_str::<serde_json::Value>(&payload)
        .map_err(|error| format!("Invalid snapshot JSON: {error}"))?;
    let mut connection = database.0.lock().map_err(|error| error.to_string())?;
    write_snapshot(&mut connection, &payload).map_err(|error| error.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .setup(|app| {
            let app_data = app.path().app_data_dir()?;
            fs::create_dir_all(&app_data)?;
            let mut connection = Connection::open(app_data.join(DATABASE_FILE))?;
            migrate(&mut connection)?;
            app.manage(DatabaseState(Mutex::new(connection)));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![load_snapshot, save_snapshot])
        .run(tauri::generate_context!())
        .expect("failed to run Fluxday");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn migration_is_idempotent_and_snapshot_write_is_atomic() {
        let mut connection = Connection::open_in_memory().unwrap();
        migrate(&mut connection).unwrap();
        migrate(&mut connection).unwrap();
        write_snapshot(&mut connection, r#"{"schemaVersion":1}"#).unwrap();
        write_snapshot(&mut connection, r#"{"schemaVersion":1,"updated":true}"#).unwrap();

        let version: i64 = connection
            .query_row("PRAGMA user_version", [], |row| row.get(0))
            .unwrap();
        let count: i64 = connection
            .query_row("SELECT COUNT(*) FROM app_state", [], |row| row.get(0))
            .unwrap();
        let payload: String = connection
            .query_row("SELECT payload FROM app_state WHERE id = 1", [], |row| {
                row.get(0)
            })
            .unwrap();

        assert_eq!(version, SCHEMA_VERSION);
        assert_eq!(count, 1);
        assert!(payload.contains("updated"));
    }
}
