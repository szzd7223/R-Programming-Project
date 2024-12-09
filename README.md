# Expense Tracker

This is a Shiny web application for tracking expenses. It provides a dashboard to visualize expenses, add new expenses, and view detailed analytics.

## Prerequisites

- R (version 4.0 or later)
- RStudio (optional, but recommended)
- MySQL Server

## Installation

1. **Clone the Repository**

   Clone this repository to your local machine using:
   ```bash
   git clone https://github.com/szzd7223/R-Programming-Project.git
   ```

2. **Install R Packages**

   Open R or RStudio and run the following command to install the required packages:

   ```r
   install.packages(c("shiny", "shinydashboard", "DBI", "RMySQL", "dplyr", "lubridate", "plotly", "shinyjs", "DT"))
   ```

## Database Setup

1. **Start MySQL Server**

   Ensure that your MySQL server is running. You can start it using the command line or through a GUI tool like MySQL Workbench.

2. **Configure Database Connection**

   Update the database connection parameters in `setup_database.R` and `app.R` if needed. The default parameters are:

   ```r
   db_name <- "expense_tracker"
   db_host <- "localhost"
   db_user <- "root"
   db_password <- "ssss"  # Update this to your MySQL root password
   ```

3. **Run Database Setup Script**

   Execute the `setup_database.R` script to create the necessary database and tables. You can do this by running:

   ```bash
   Rscript setup_database.R
   ```

   This script will create a database named `expense_tracker` and set up the required tables (`expenses` and `categories`).

## Running the Application

To run the application, open `app.R` in RStudio or run it directly using R:

```bash
Rscript app.R
```

The application will start, and you can access it through your web browser.

## Usage

- **Dashboard**: View a summary of your expenses.
- **Add Expense**: Add new expenses with details like date, amount, and category.
- **View Expenses**: See a detailed table of all recorded expenses.
- **Analytics**: Visualize expenses through various charts and graphs.
