########################### Set up environment #################################
# load required packages
library(lubridate)
library(dplyr)
library(magrittr)
library(stringr)
library(rvest)
library(ggplot2)
library(grid)
library(scales)
library(leaflet)
library(shiny)
library(DT)
library(circlize)
library(readr)
library(plyr)
library(lubridate)
library(magrittr)
library(dplyr)
library(tidyr)
library(tibbletime)
library(ggplot2)
library(randomForest)
library(Metrics)
library(zoo)
library(gbm)
library(MASS)
library(TTR)
library(shiny)
library(shinydashboard)
library(e1071)
library(plotly)


# set up some colours to use
DarkBlue <- rgb(red = 0, green = 51, blue = 141, maxColorValue = 255)
Purple <- rgb(red = 142, green = 37, blue = 141, maxColorValue = 255)
lightGrey <- rgb(red = 186, green = 187, blue = 188, maxColorValue = 255)


# run the scripts that get, clean and combine the data together
homeC_clean_2014 <- read.csv("homeC_clean_2014.csv")
homeC_clean_2015 <- read.csv("homeC_clean_2015.csv")
homeC_clean_2016 <- read.csv("homeC_clean_2016.csv")
daily_factors_all_years <- read.csv("homeC_daily_factors.csv")
homeC_clean_all_years <- rbind(homeC_clean_2014,homeC_clean_2015,homeC_clean_2016)

homeC_clean_predictors_hourly <- read.csv("homeC_clean_predictors_hourly.csv")
homeC_clean_predictors_hourly$dateTime<-as.Date(homeC_clean_predictors_hourly$dateTime)

# Establish a new column for peak our for solar power generation
# peak_time<-function(df){
#   timeDummy <- as.numeric(0:23)[df$time]
#   for (i in 1:nrow(df)){
#     if(timeDummy[i]>=9&timeDummy[i]<=17){
#       df$pk_time[i] <- "yes"
#     } else{
#       df$pk_time[i] <- "no"
#     } # end else
#   }
#   return(df);
# }
# homeC_clean_2014 <- peak_time(homeC_clean_2014);
# homeC_clean_2015 <- peak_time(homeC_clean_2015);
# homeC_clean_2016 <- peak_time(homeC_clean_2016);
# homeC_clean_all_years <- peak_time(homeC_clean_all_years);
# write.csv(homeC_clean_2014, file = "homeC_clean_2014.csv")
# write.csv(homeC_clean_2015, file = "homeC_clean_2015.csv")
# write.csv(homeC_clean_2016, file = "homeC_clean_2016.csv")
# write.csv(homeC_clean_all_years, file = "homeC_clean_all_years.csv")

# Solar Power Generation Helper Functions:
source("./get_sol_data.R")
source("./plot_sol_model.R")
source("./eval_sol_model_1.R")

# Power Use Helper Functions:
source("./get_use_data.R")
source("./plot_use_model.R")
source("./eval_use_model_1.R")

source("./SummaryStatsFunctions.R")

##### end helper functions ##### 

# initialize state of dashboard to something that works 
view_window_start = "2016-01-30"
view_window_end = "2016-04-05"
forcast_horizon = 7
start_date = "2014-01-07" # start late due to ewa needing time for its last week trend
end_date = "2016-11-05"
train_end_date = "2016-01-01"
level_of_data = "daily"
time_period = "late evening"

xlim <- c(as.Date("2014-01-02"),as.Date("2016-12-01"))
ylim <- c(1,5)


# establish shiny server -------------------------------------------------------
shinyServer( function(input, output) {
  
  ranges <- reactiveValues(x = NULL, y = NULL)
  
  # When a double-click happens, check if there's a brush on the plot.
  # If so, zoom to the brush bounds; if not, reset the zoom.
  observeEvent(input$plot3_dblclick, {
    brush <- input$plot3_brush
    if (!is.null(brush)) {
      ranges$x <- c(brush$xmin, brush$xmax)
      
      ranges$y <- c(brush$ymin, brush$ymax)
      
    } else {
      ranges$x <- NULL
      ranges$y <- NULL
    }
  })
    
   # zoomable plot
   # output plot 3
  output$plot3 <- renderPlot({
    
    if (!is.null(ranges$x)) {
    ranges$x <- as.Date(ranges$x,origin = "1970-01-01")
    }
    plot3<-plot_variable(homeC_clean_predictors_hourly,input$variable_to_plot,xlim=ranges$x,ylim=ranges$y)
    
    plot3
  })
  
  # output plot 4, histogram in the summary statistics tab
  output$plot4 <- renderPlotly({
    
    plot4 <- plot_histogram(homeC_clean_predictors_hourly,input$variable_to_plot) 
    
    plot4
  })
  
  # output plot 1
  output$plot1 <- renderPlotly({
    
    use_data <- get_use_data(homeC_clean_all_years,daily_factors_all_years,input$time_period,
                                         level_of_data,input$slider)
    use_data$forecast_date <- lead(as.numeric(use_data$dateTime),input$slider)
    use_data$forecast_date <- as.Date(use_data$forecast_date)
    model <- eval_use_model_1(use_data,input$date_range[1], input$date_range[2],
                              input$train_date,input$slider)  
    obj2 <- model[[3]] 
    plot <- plot_use_model(obj2,input$window_range[1],input$window_range[2])
    plot 
  }) 
  # output text 1
  output$text1 <- renderText({
    use_data <- get_use_data(homeC_clean_all_years,daily_factors_all_years,input$time_period,
                             level_of_data,input$slider)
    use_data$forecast_date <- lead(as.numeric(use_data$dateTime),input$slider)
    use_data$forecast_date <- as.Date(use_data$forecast_date)
    obj <- use_data
    model <- eval_use_model_1(obj, input$date_range[1], input$date_range[2],
                              input$train_date, input$slider)  
    model[[1]]
  })
  # output table
  output$table <- renderDataTable({
    use_data <- get_use_data(homeC_clean_all_years,daily_factors_all_years,input$time_period,
                             level_of_data,input$slider)
    use_data$forecast_date <- lead(as.numeric(use_data$dateTime),input$slider)
    use_data$forecast_date <- as.Date(use_data$forecast_date)
    model <- eval_use_model_1(use_data,input$date_range[1], input$date_range[2],
                              input$train_date,input$slider)  
    # for data table output
    obj3 <- model[[3]] %>% dplyr::select(dateTime,forecast_date,future_use,
                                         gbm_pred) %>% dplyr::rename("Date" = dateTime,"Forecast Date"=forecast_date,
                                                              "Actual Forecast Date Use [kW]" = future_use, "Model Prediction [kW]"=gbm_pred)
    # allows me to give a default length to the table, datatable function from DT package
    datatable(obj3,
              options = list(
                "pageLength" = 10))})
  
  # output table 3
  output$table3 <- renderDataTable({
    
    summary_stats_df<-get_summary_stats(homeC_clean_predictors_hourly,input$variable_to_plot, input$month)
    
    obj4 <- summary_stats_df
    
    datatable(obj4)
    
  })
  
  #### Solar Power Generation Outputs: ####
  # output plot 2
  output$plot2 <- renderPlotly({
    
    processed_data <- get_sol_data.f(homeC_clean_all_years,daily_factors_all_years,input$peak_time,
                                         level_of_data,input$solslide)
    processed_data$forecast_date <- lead(as.numeric(processed_data$dateTime),input$solslide)
    processed_data$forecast_date <- as.Date(processed_data$forecast_date)
    model <- eval_sol_model_1.f(processed_data,input$sol_date_range[1], input$sol_date_range[2],
                              input$sol_train_date,input$solslide)  
    obj2 <- model[[3]] 
    plot <- plot_sol_model.f(obj2,input$sol_win_range[1],input$sol_win_range[2])
    plot
  })
  # output text 2
  output$text2 <- renderText({
    processed_data <- get_sol_data.f(homeC_clean_all_years,daily_factors_all_years,input$peak_time,
                                         level_of_data,input$solslide)
    processed_data$forecast_date <- lead(as.numeric(processed_data$dateTime),input$solslide)
    processed_data$forecast_date <- as.Date(processed_data$forecast_date)
    obj <- processed_data
    model <- eval_sol_model_1.f(obj, input$sol_date_range[1], input$sol_date_range[2],
                              input$sol_train_date, input$solslide)  
    model[[1]]
  })
  # output table 2
  output$table2 <- renderDataTable({
    processed_data <- get_sol_data.f(homeC_clean_all_years,daily_factors_all_years,input$peak_time,
                                         level_of_data,input$solslide)
    processed_data$forecast_date <- lead(as.numeric(processed_data$dateTime),input$solslide)
    processed_data$forecast_date <- as.Date(processed_data$forecast_date)
    model <- eval_sol_model_1.f(processed_data,input$sol_date_range[1], input$sol_date_range[2],
                              input$sol_train_date,input$solslide)  
    # for data table output
    obj3 <- model[[3]] %>% dplyr::select(dateTime,forecast_date,future_gen,
                                         gbm_pred) %>% dplyr::rename("Date" = dateTime,"Forecast Date"=forecast_date,
                                                              "Actual Forecast Date Gen [kW]" = future_gen, "Model Prediction [kW]"=gbm_pred)
    # allows me to give a default length to the table, datatable function from DT package
    datatable(obj3,
              options = list(
                "pageLength" = 10))})
  
  
output$cat1 <- renderImage({
  # When input$n is 3, filename is ./images/image3.jpeg
  filename <- normalizePath(paste(getwd(), '/cat1.jpeg', sep = ''))
  
  # Return a list containing the filename and alt text
  list(src = filename,
       alt = paste("Image number", input$n))
  
}, deleteFile = FALSE)
})
