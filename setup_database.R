library(DBI)
library(RMySQL)

# Database connection parameters
db_name <- "expense_tracker"
db_host <- "localhost"
db_user <- "root"
db_password <- "ssss"  # Updated password

# Create database and tables
setup_database <- function() {
  # Connect to MySQL (without selecting a database)
  con <- dbConnect(MySQL(),
                  host = db_host,
                  user = db_user,
                  password = db_password)

  # Create database if it doesn't exist
  dbExecute(con, sprintf("CREATE DATABASE IF NOT EXISTS %s", db_name))

  # Disconnect and reconnect to the new database
  dbDisconnect(con)
  con <- dbConnect(MySQL(),
                  host = db_host,
                  user = db_user,
                  password = db_password,
                  dbname = db_name)

  # Create expenses table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS expenses (
      id INT AUTO_INCREMENT PRIMARY KEY,
      date DATE NOT NULL,
      amount DECIMAL(10,2) NOT NULL,
      category VARCHAR(50) NOT NULL,
      description TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Create categories table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS categories (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(50) NOT NULL UNIQUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Insert default categories
  default_categories <- c("Food", "Transportation", "Utilities",
                         "Entertainment", "Shopping", "Healthcare", "Others")

  for (category in default_categories) {
    dbExecute(con, sprintf("
      INSERT IGNORE INTO categories (name) VALUES ('%s')
    ", category))
  }

  # Close connection
  dbDisconnect(con)

  cat("Database and tables created successfully!\n")
}

# Run setup
tryCatch({
  setup_database()
}, error = function(e) {
  cat("Error setting up database:", e$message, "\n")
})

