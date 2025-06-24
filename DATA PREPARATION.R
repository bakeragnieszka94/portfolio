
#################################
#######DATA PREPARATION##########
################################
#The street-level crime, outcome, and stop and search datasets from each month 
#were merged using the date to create datasets from each component for the last 13 months.
#And Join street + outcome by Crime.ID (left join)
# packages 
library(dplyr)
library(readr)

# Set folder path
# Packages
library(dplyr)
library(readr)

# Set folder path
folder_path <- "C:/Users/44772/OneDrive/Desktop/competetive advantage"

# Check if folder exists
if (!dir.exists(folder_path)) stop("folder not found!")

# Set start and end months for data range
start_month <- as.Date("2024-02-01")
end_month <- as.Date("2025-02-01")

# Generate monthly dates between start and end
months <- seq(from = start_month, to = end_month, by = "month")
month_strings <- format(months, "%Y-%m")

# Create empty lists to store each dataset
stop_and_search_list <- list()
outcomes_list <- list()
street_list <- list()

# Loop through months to process each month's data for stop-and-search, outcomes, and street
for (month_str in month_strings) {
  
  # Display the month being processed
  message("📅 Processing: ", month_str)
  
  # Build file paths for each dataset
  outcome_file     <- file.path(folder_path, paste0(month_str, "-northumbria-outcomes.csv"))
  street_file      <- file.path(folder_path, paste0(month_str, "-northumbria-street.csv"))
  
  # Check if all files exist for the current month
  if (file.exists(stop_search_file) && file.exists(outcome_file) && file.exists(street_file)) {
    message("Found all files for ", month_str)
    
    # Load the CSV files
    outcome_data     <- read_csv(outcome_file, show_col_types = FALSE)
    street_data      <- read_csv(street_file, show_col_types = FALSE)
    
    # Add Source labels to each dataset
    outcome_data$Source     <- "Outcome"
    street_data$Source      <- "Street"
    
    # Add Month column to each dataset
    outcome_data$Month      <- month_str
    street_data$Month       <- month_str
    
    # Store the data in the respective lists
    outcomes_list[[month_str]]         <- outcome_data
    street_list[[month_str]]           <- street_data
  } else {
    message("⚠️ Missing file(s) for ", month_str)
  }
}

# Combine all datasets for each component
outcomes_combined        <- bind_rows(outcomes_list)
street_combined          <- bind_rows(street_list)

# Check the first few rows of each combined dataset

message("✅ Combined Outcomes Data:")
print(head(outcomes_combined))

message("✅ Combined Street Data:")
print(head(street_combined))

# Optionally, you can check how many months are in each combined dataset

unique_months_outcomes <- unique(outcomes_combined$Month)
num_months_outcomes <- length(unique_months_outcomes)
message("Total number of months in Outcomes data: ", num_months_outcomes)

unique_months_street <- unique(street_combined$Month)
num_months_street <- length(unique_months_street)
message("Total number of months in Street data: ", num_months_street)


#join between the two datasets (outcomes_combined and street_combined) on the Crime ID column.
# Perform a left join to keep all outcomes data and add street data where Crime ID matches
combined_data1 <- left_join(outcomes_combined, street_combined, by = "Crime ID")

# Check the result
message("✅ Combined Data by Crime ID:")
print(head(combined_data1))

# Optionally, check the number of unique Crime IDs in the combined dataset
num_unique_crime_ids <- length(unique(combined_data1$`Crime ID`))
message("Total number of unique Crime IDs in the combined data: ", num_unique_crime_ids)


######################################
##NOW COMBINE WITH LSOA##############
#####################################

#the LSOA code, Local authority, was selected from the LSOA North East dataset.

glimpse(combined_data1)

#remove duplicate columns
library(dplyr)

combined_data1 <- combined_data1 %>%
  select(-ends_with(".y"))

#Join with LSOA to get larger areas informations
LSOA_NE <- read_excel("LSOA_NE.xlsx")
#viwe dataset
glimpse(LSOA_NE)
#select colum LSOA code and Local authority
LSOA_NE <- LSOA_NE %>% select(`LSOA code`, `Local authority`)
#Join with combined dataset
combined_data1 <- combined_data1 %>%
  left_join(LSOA_NE, by = c("LSOA code.x" = "LSOA code"))
#view final data 
glimpse(combined_data1)
#Chcek for missing variable in columns
colSums(is.na(combined_data1))
#check local autoriti column
sum(is.na(combined_data1$`Local authority`))
#check rows
combined_data1 %>%
  filter(is.na(`Local authority`))
#check unique LSOA name.x values where Local authority is NA
combined_data1 %>%
  filter(is.na(`Local authority`)) %>%
  distinct(`LSOA name.x`) %>%
  arrange(`LSOA name.x`) %>%
  print(n = Inf)

glimpse(combined_data1)

#check local authority column:
combined_data1 %>%
  filter(!is.na(`Local authority`)) %>%
  distinct(`Local authority`) %>%
  arrange(`Local authority`) %>%
  print(n = Inf)

#some LSOA need manually assign Local authority
library(dplyr)

combined_data1 <- combined_data1 %>%
  mutate(`Local authority` = case_when(
    is.na(`Local authority`) & grepl("^Sunderland", `LSOA name.x`) ~ "Sunderland",
    is.na(`Local authority`) & grepl("^Gateshead", `LSOA name.x`) ~ "Gateshead",
    is.na(`Local authority`) & grepl("^Newcastle upon Tyne", `LSOA name.x`) ~ "Newcastle upon Tyne",
    is.na(`Local authority`) & grepl("^North Tyneside", `LSOA name.x`) ~ "North Tyneside",
    is.na(`Local authority`) & grepl("^Northumberland", `LSOA name.x`) ~ "Northumberland",
    is.na(`Local authority`) & grepl("^South Tyneside", `LSOA name.x`) ~ "South Tyneside",
    is.na(`Local authority`) & grepl("^County Durham", `LSOA name.x`) ~ "County Durham",
    TRUE ~ `Local authority`
  ))
#Now chcek missing values again
combined_data1 %>%
  filter(is.na(`Local authority`)) %>%
  distinct(`LSOA name.x`)

#Chcek for missing variable in columns again
colSums(is.na(combined_data1))
#remove missing authority 
combined_data1 <- combined_data1 %>%
  drop_na(`Local authority`)

#check crime column
combined_data1 %>%
  filter(is.na(`Crime type`)) %>%
  print(n = Inf)

#Impute the missing values for last outcome and crime type (UNKNOW)
# Impute missing Crime type and Last outcome category with "Unknown"
combined_data1 <- combined_data1 %>%
  mutate(
    `Crime type` = if_else(is.na(`Crime type`), "Unknown", `Crime type`),
    `Last outcome category` = if_else(is.na(`Last outcome category`), "Unknown", `Last outcome category`)
  )

# Verify that missing values have been imputed
colSums(is.na(combined_data1))

#Now tidy data remoxe 'x' from columns names 
glimpse(combined_data1)
# Remove '.x' from column names
colnames(combined_data1) <- gsub("\\.x$", "", colnames(combined_data1))
#Save final 
# Save as a CSV file
write.csv(combined_data1, "outcomes_and_street_clean.csv", row.names = FALSE)
# Save as an RDS file
saveRDS(combined_data1, "outcomes_and_street_clean.rds")

skim(combined_data1)

unique(combined_data1$`Last outcome category`)



