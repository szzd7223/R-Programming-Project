library(shiny)
library(shinydashboard)
library(DBI)
library(RMySQL)
library(dplyr)
library(lubridate)
library(plotly)
library(shinyjs)
library(DT)

# UI Definition
ui <- dashboardPage(
  dashboardHeader(title = "Expense Tracker"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Add Expense", tabName = "add_expense", icon = icon("plus")),
      menuItem("View Expenses", tabName = "view_expenses", icon = icon("table")),
      menuItem("Analytics", tabName = "analytics", icon = icon("chart-line"))
    )
  ),
  
  dashboardBody(
    useShinyjs(),
    tabItems(
      # Dashboard Tab
      tabItem(tabName = "dashboard",
        fluidRow(
          valueBoxOutput("total_month_expense"),
          valueBoxOutput("most_expensive_category"),
          valueBoxOutput("total_expenses")
        ),
        fluidRow(
          box(plotlyOutput("monthly_trend"), width = 8, title = "Monthly Expenses"),
          box(plotlyOutput("category_pie"), width = 4, title = "Category Distribution")
        )
      ),
      
      # Add Expense Tab
      tabItem(tabName = "add_expense",
        fluidRow(
          box(
            title = "Add New Expense",
            width = 6,
            dateInput("expense_date", "Date:", value = Sys.Date()),
            numericInput("amount", "Amount:", value = 0, min = 0),
            selectInput("category", "Category:", 
                       choices = c("Food", "Transportation", "Utilities", 
                                 "Entertainment", "Shopping", "Healthcare", 
                                 "Others")),
            textInput("description", "Description:"),
            actionButton("submit", "Add Expense", class = "btn-primary")
          )
        )
      ),
      
      # View Expenses Tab
      tabItem(tabName = "view_expenses",
        fluidRow(
          box(
            width = 12,
            title = "Expense Records",
            dateRangeInput("date_range", "Filter by Date Range:",
                          start = Sys.Date() - 30, end = Sys.Date()),
            DTOutput("expense_table")
          )
        )
      ),
      
      # Analytics Tab
      tabItem(tabName = "analytics",
        fluidRow(
          box(
            width = 12,
            title = "Monthly Spending Trends",
            plotlyOutput("spending_trends")
          )
        ),
        fluidRow(
          box(
            width = 6,
            title = "Category-wise Analysis",
            plotlyOutput("category_analysis")
          ),
          box(
            width = 6,
            title = "Top Expenses",
            plotlyOutput("top_expenses")
          )
        )
      )
    )
  )
)

# Server Logic
server <- function(input, output, session) {
  # Database connection with error handling
  con <- tryCatch({
    dbConnect(
      MySQL(),
      dbname = "expense_tracker",
      host = "localhost",
      user = "root",
      password = "ssss"
    )
  }, error = function(e) {
    showNotification(
      paste("Database connection failed:", e$message),
      type = "error",
      duration = NULL
    )
    NULL
  })

  # Reactive values for storing data
  values <- reactiveValues(
    expenses = NULL,
    update_trigger = 0,
    db_connected = !is.null(con)
  )
  
  # Load expenses with error handling
  observe({
    if (values$db_connected) {
      values$update_trigger  # dependency on updates
      tryCatch({
        # Fetch data and properly convert date column
        values$expenses <- dbGetQuery(con, "SELECT * FROM expenses ORDER BY date DESC") %>%
          mutate(
            date = as.Date(date),
            amount = as.numeric(amount),
            description = as.character(description)
          )
      }, error = function(e) {
        showNotification(
          paste("Failed to load expenses:", e$message),
          type = "error"
        )
      })
    }
  })
  
  # Add expense handler
  observeEvent(input$submit, {
    if (!values$db_connected) {
      showNotification("Database not connected. Cannot add expense.", type = "error")
      return()
    }
    
    if (input$amount > 0) {
      tryCatch({
        # Sanitize inputs and create proper MySQL query
        safe_date <- format(input$expense_date, "%Y-%m-%d")
        safe_amount <- as.numeric(input$amount)
        safe_category <- gsub("'", "''", input$category)  # Escape single quotes
        safe_description <- gsub("'", "''", input$description)  # Escape single quotes
        
        query <- sprintf(
          "INSERT INTO expenses (date, amount, category, description) VALUES ('%s', %.2f, '%s', '%s')",
          safe_date, safe_amount, safe_category, safe_description
        )
        
        dbExecute(con, query)
        values$update_trigger <- values$update_trigger + 1
        showNotification("Expense added successfully!", type = "message")
        
        # Reset input fields
        updateNumericInput(session, "amount", value = 0)
        updateTextInput(session, "description", value = "")
      }, error = function(e) {
        showNotification(paste("Failed to add expense:", e$message), type = "error")
      })
    } else {
      showNotification("Amount must be greater than 0", type = "warning")
    }
  })
  
  # Dashboard outputs
  output$total_month_expense <- renderValueBox({
    if (!values$db_connected) {
      valueBox("N/A", "Database Not Connected", icon = icon("database"), color = "red")
    } else {
      req(values$expenses)
      current_month_expenses <- sum(values$expenses$amount[
        month(values$expenses$date) == month(Sys.Date()) &
        year(values$expenses$date) == year(Sys.Date())
      ])
      valueBox(
        paste0("₹", format(current_month_expenses, big.mark = ",")),
        "This Month's Expenses",
        icon = icon("indian-rupee-sign"),
        color = "green"
      )
    }
  })
  
  output$most_expensive_category <- renderValueBox({
    if (!values$db_connected) {
      valueBox("N/A", "Database Not Connected", icon = icon("database"), color = "red")
    } else {
      req(values$expenses)
      category_sums <- aggregate(amount ~ category, data = values$expenses, sum)
      if(nrow(category_sums) > 0) {
        top_category <- category_sums[which.max(category_sums$amount), ]
        valueBox(
          top_category$category,
          "Highest Spending Category",
          icon = icon("tags"),
          color = "red"
        )
      }
    }
  })
  
  output$total_expenses <- renderValueBox({
    if (!values$db_connected) {
      valueBox("N/A", "Database Not Connected", icon = icon("database"), color = "red")
    } else {
      req(values$expenses)
      total <- sum(values$expenses$amount)
      valueBox(
        paste0("₹", format(total, big.mark = ",")),
        "Total Expenses",
        icon = icon("wallet"),
        color = "blue"
      )
    }
  })
  
  # Monthly trend plot
  output$monthly_trend <- renderPlotly({
    req(values$expenses)
    if(nrow(values$expenses) == 0) {
      return(plot_ly() %>% 
        layout(title = "No expenses recorded yet",
               xaxis = list(title = "Month"),
               yaxis = list(title = "Total Expense (₹)")))
    }
    
    # Summarize monthly data with proper date handling
    monthly_data <- values$expenses %>%
      mutate(
        month = format(date, "%Y-%m-01")
      ) %>%
      group_by(month) %>%
      summarise(
        total = sum(as.numeric(amount), na.rm = TRUE)
      ) %>%
      mutate(
        month = as.Date(month)
      ) %>%
      arrange(month)
    
    # Create the plot
    p <- plot_ly(
      data = monthly_data,
      x = ~month,
      y = ~total,
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#1f77b4"),
      marker = list(color = "#1f77b4")
    ) %>%
      layout(
        title = list(text = "Monthly Expense Trend", font = list(size = 16)),
        xaxis = list(
          title = "Month",
          tickformat = "%b %Y",
          tickangle = 45
        ),
        yaxis = list(
          title = "Total Expense (₹)",
          tickformat = ",",
          hoverformat = ",.0f"
        ),
        showlegend = FALSE,
        hovermode = "x unified"
      )
    
    return(p)
  })
  
  # Category pie chart
  output$category_pie <- renderPlotly({
    req(values$expenses)
    category_data <- values$expenses %>%
      group_by(category) %>%
      summarise(total = sum(amount))
    
    plot_ly(category_data, labels = ~category, values = ~total, type = "pie") %>%
      layout(title = "Expenses by Category")
  })
  
  # Expense table with filtering
  output$expense_table <- renderDT({
    req(values$expenses)
    filtered_data <- values$expenses %>%
      filter(date >= input$date_range[1] & date <= input$date_range[2])
    
    datatable(filtered_data,
              options = list(pageLength = 10,
                           order = list(list(1, 'desc'))),
              rownames = FALSE) %>%
      formatCurrency(columns = "amount", currency = "₹")
  })
  
  # Analytics plots
  output$spending_trends <- renderPlotly({
    req(values$expenses)
    daily_spend <- values$expenses %>%
      group_by(date) %>%
      summarise(total = sum(amount))
    
    plot_ly(daily_spend, x = ~date, y = ~total, type = "scatter", mode = "lines") %>%
      layout(title = "Daily Spending Pattern",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Amount (₹)"))
  })
  
  output$category_analysis <- renderPlotly({
    req(values$expenses)
    category_monthly <- values$expenses %>%
      mutate(month = floor_date(date, "month")) %>%
      group_by(month, category) %>%
      summarise(total = sum(amount))
    
    plot_ly(category_monthly, x = ~month, y = ~total, color = ~category, type = "bar") %>%
      layout(title = "Monthly Category-wise Spending",
             barmode = "stack",
             xaxis = list(title = "Month"),
             yaxis = list(title = "Amount (₹)"))
  })
  
  output$top_expenses <- renderPlotly({
    req(values$expenses)
    top_10 <- values$expenses %>%
      arrange(desc(amount)) %>%
      head(10)
    
    plot_ly(top_10, x = ~reorder(description, amount), y = ~amount, type = "bar") %>%
      layout(title = "Top 10 Expenses",
             xaxis = list(title = "Description"),
             yaxis = list(title = "Amount (₹)"))
  })
  
  # Cleanup with error handling
  session$onSessionEnded(function() {
    if (!is.null(con)) {
      tryCatch({
        dbDisconnect(con)
      }, error = function(e) {
        warning("Error disconnecting from database:", e$message)
      })
    }
  })
}

# Run the app
shinyApp(ui = ui, server = server)
