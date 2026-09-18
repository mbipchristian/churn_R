library(shiny)
library(tidyverse)
library(arrow)

# Charger les données
dataset <- read_parquet("data/processed/dataset_clean.parquet")

ui <- fluidPage(
  titlePanel("Dashboard Clients"),
  
  sidebarLayout(
    sidebarPanel(
      # FILTRE
      selectInput(
        "region_filter",
        "Choisir une région :",
        choices = c("Toutes", unique(dataset$region_group)),
        selected = "Toutes"
      )
    ),
    
    mainPanel(
      # KPI
      fluidRow(
        column(6, h3("Clients actifs"), textOutput("kpi_active")),
        column(6, h3("Clients totaux"), textOutput("kpi_total"))
      ),
      
      # GRAPHIQUE
      plotOutput("recency_plot"),
      
      # TABLE
      tableOutput("table_clients")
    )
  )
)

server <- function(input, output) {
  
  # Données filtrées
  data_filtered <- reactive({
    if (input$region_filter == "Toutes") {
      dataset
    } else {
      dataset %>% filter(region_group == input$region_filter)
    }
  })
  
  # KPI 1
  output$kpi_active <- renderText({
    sum(data_filtered()$is_active == "yes", na.rm = TRUE)
  })
  
  # KPI 2
  output$kpi_total <- renderText({
    nrow(data_filtered())
  })
  
  # Graphique
  output$recency_plot <- renderPlot({
    data_filtered() %>%
      ggplot(aes(x = recency_days, fill = is_active)) +
      geom_histogram(bins = 30, alpha = 0.6, position = "identity") +
      theme_minimal() +
      labs(title = "Récence des clients")
  })
  
  # Table
  output$table_clients <- renderTable({
    data_filtered() %>%
      select(customer_id, age, region_group, is_active) %>%
      head(10)
  })
}

shinyApp(ui = ui, server = server)