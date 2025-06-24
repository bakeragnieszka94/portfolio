#PREDICTIVE ANALISIS
library(lubridate)
library(tidyr)
library(tidyverse)
library(ggplot2)
#1.1. Data Preparation
data_crime <- read.csv("outcomes_and_street_clean.csv")
glimpse(data_crime)
#Hotspot Analysis

# Load required libraries
library(ggplot2)
library(sf)
#Simple plot vs location
# Convert data to a spatial object
crime_sf <- st_as_sf(data_crime, coords = c("Longitude", "Latitude"), crs = 4326)

# Plot crime locations
ggplot(data = crime_sf) +
  geom_sf(aes(color = Crime.type), alpha = 0.5) +
  labs(title = "Crime Locations by Type") +
  theme_minimal()


#Density Map - KDE
#1. Packages
install.packages(c("sf", "spatstat", "ggplot2", "tmap", "dplyr", "spdep"))
#2.Data preparation
library(sf)
library(dplyr)

# Project to a metric CRS (important for distance-based methods like KDE)
crime_sf <- st_transform(crime_sf, crs = 27700)  # British National Grid
#Kernel Density Estimation (KDE)
library(spatstat)

# Convert sf to ppp object (used by spatstat)
library(sf)
library(spatstat)

# 1.Convert your data to sf and reproject
crime_sf <- st_as_sf(data_crime, coords = c("Longitude", "Latitude"), crs = 4326)
crime_sf <- st_transform(crime_sf, crs = 27700)  # Use metric system (British National Grid)

# 2. Extract coordinates
coords <- st_coordinates(crime_sf)

#3.Jitter the coordinates to avoid duplicates
coords_jittered <- jitter(as.matrix(coords), amount = 1)  # 1 meter jitter, can adjust if needed

# 4.Create window for spatstat analysis
win <- owin(range(coords_jittered[,1]), range(coords_jittered[,2]))

# 5.Create ppp object with jittered coordinates
crime_ppp_jittered <- ppp(x = coords_jittered[,1], y = coords_jittered[,2], window = win)

# 6. KDE with jittered points
density_map <- density(crime_ppp_jittered, sigma = 1000)  # You can adjust sigma too
plot(density_map, main = "Crime KDE")

###############################################
#Getis-Ord Gi* Statistic (Hotspot Detection)###
##############################################

library(dplyr)

# Aggregate crime data by latitude and longitude (or by LSOA code if preferred)
crime_frequency <- data_crime %>%
  group_by(Latitude, Longitude) %>%
  summarise(crime_count = n())

# View the aggregated data
head(crime_frequency)

# sjow more digits in location for more precise location
crime_frequency$Latitude <- format(crime_frequency$Latitude, scientific = FALSE, digits = 15)
crime_frequency$Longitude <- format(crime_frequency$Longitude, scientific = FALSE, digits = 15)


# Reorder the crime_frequency tibble by crime_count in descending order
crime_frequency <- crime_frequency %>%
  arrange(desc(crime_count))

# Print the first 10 rows with the locations with most crimes 
print(crime_frequency, n = 10)


#Create a Spatial Object
library(sf)

# Convert crime data to an sf object with lat and lon as coordinates
crime_sf <- st_as_sf(crime_frequency, coords = c("Longitude", "Latitude"), crs = 4326)

# Check the result
print(crime_sf)
#Creating a Correct Distance Matrix:

# Reproject the data to a CRS that uses meters (e.g., EPSG:3395)
crime_sf_proj <- st_transform(crime_sf, crs = 3395)

# Calculate the distance matrix from each point to all others
distance_matrix <- st_distance(crime_sf_proj)

# Print the distance matrix and its dimensions
print(distance_matrix)
print(dim(distance_matrix))
#Creating a Neighbors List Based on Distance
# Convert the distance matrix to a regular numeric matrix (in meters)
distance_matrix_numeric <- as.numeric(distance_matrix)
# Reshape the numeric vector into a matrix
distance_matrix_matrix <- matrix(distance_matrix_numeric, nrow = nrow(distance_matrix), byrow = TRUE)
# Define a distance threshold (in meters)
threshold <- 1000  # 1 km
# Create neighbors list based on the threshold distance (neighbors within 1 km)
neighbors <- lapply(1:nrow(distance_matrix_matrix), function(i) {
  # Select neighbors whose distance is within the threshold
  which(distance_matrix_matrix[i, ] <= threshold)
})
#Check the first few neighbors
print(neighbors[1:5])  # Prints first 5 neighbors
#Calculate Getis-Ord Gi* Statistic
# Create a weights matrix where each row corresponds to a crime point and each column corresponds to a neighboring crime point
weights_matrix <- matrix(0, nrow = nrow(crime_frequency), ncol = nrow(crime_frequency))
# Fill in the weights matrix based on the neighbors list
for (i in 1:nrow(crime_frequency)) {
  neighbors_i <- neighbors[[i]]
  weights_matrix[i, neighbors_i] <- 1
}
#spdep package for spatial analysis
library(spdep)
# Create a spatial weights object using the weights matrix
listw <- mat2listw(weights_matrix, style = "W")
# Calculate the Getis-Ord Gi* statistic for each point
gi_star_result <- localG(crime_frequency$crime_count, listw)
# View the results (Gi* statistic for each point)
head(gi_star_result)
# Add Gi* results to the crime frequency data
crime_frequency$gi_star <- gi_star_result
# View the updated crime data with Gi* values
head(crime_frequency)
# Extract the numeric values from the localG object
gi_star_values <- as.numeric(gi_star_result)
# Add the numeric Gi* values to crime data
crime_frequency$gi_star_numeric <- gi_star_values
# View the updated crime data with Gi* values in numeric format
head(crime_frequency)

#Visualize Hotspots and Coldspots
# Plot crime data with Gi* values as colors
ggplot(crime_frequency) +
  geom_point(aes(x = Longitude, y = Latitude, color = gi_star_numeric)) +
  scale_color_gradient2(low = "blue", high = "red", mid = "white", midpoint = 0)+
  theme_minimal() +
  labs(title = "Crime Hotspots and Coldspots", x = "Longitude", y = "Latitude", color = "Gi* Value")

#Better Color Scaling to see coldspots
summary(crime_frequency$gi_star_numeric)
#symmetric scale around the max absolute value
max_abs_gi <- max(abs(crime_frequency$gi_star_numeric), na.rm = TRUE)
#plot of crime data with Gi* values as colors
ggplot(crime_frequency) +
  geom_point(aes(x = Longitude, y = Latitude, color = gi_star_numeric), alpha = 0.7) +
  scale_color_gradient2(
    low = "darkblue", mid = "white", high = "red", 
    midpoint = 0, limits = c(-max_abs_gi, max_abs_gi)
  ) +
  theme_minimal() +
  labs(
    title = "Crime Hotspots and Coldspots", 
    x = "Longitude", 
    y = "Latitude", 
    color = "Gi* Value"
  ) +
  theme(plot.title = element_text(hjust = 0.5))


#Categorise for better understandding 
#Categorise Crime Locations as Hotspots or Coldspots
crime_frequency$hotspot_status <- ifelse(crime_frequency$gi_star_numeric > 1, "Hotspot", 
                                         ifelse(crime_frequency$gi_star_numeric < -1, "Coldspot", "Neutral"))
# View the categorized data
head(crime_frequency)

#Identify Significant Hotspots or Coldspots
#Set a significance threshold for hotspots (1.96) and coldspots (-1.96)
significant_hotspot_threshold <- 1.96  
significant_coldspot_threshold <- -1.96  
#classify each point base on Gi*
crime_frequency$significance <- ifelse(
  crime_frequency$gi_star_numeric > significant_hotspot_threshold, 
  "Significant Hotspot",
  ifelse(
    crime_frequency$gi_star_numeric < significant_coldspot_threshold, 
    "Significant Coldspot", 
    "Not Significant"
  )
)

# View the updated data
head(crime_frequency)

#Print Only Significant Hotspots (Gi* > 1.96)
hotspots <- crime_frequency %>%
  filter(gi_star_numeric > 1.96)

head(hotspots)

#Print Only Significant Coldspots (Gi* < -1.96)
coldspots <- crime_frequency %>%
  filter(gi_star_numeric < -1.96)

head(coldspots)

#Both Hotspots & Coldspots Together
significant_spots <- crime_frequency %>%
  filter(gi_star_numeric > 1.96 | gi_star_numeric < -1.96)

print(significant_spots)


write.csv(crime_frequency, "crime_frequency_with_Gi_star.csv", row.names = FALSE)

#count the number of significant hotspots and coldspots within each Local Authority 
# Convert Latitude and Longitude in crime_frequency to numeric (double) type
crime_frequency <- crime_frequency %>%
  mutate(Latitude = as.numeric(Latitude), Longitude = as.numeric(Longitude))

#perform the join
data_with_gi <- data_crime %>%
  inner_join(crime_frequency, by = c("Latitude", "Longitude"))
# Check result
head(data_with_gi)

# Classify each point
data_with_gi <- data_with_gi %>%
  mutate(gi_class = case_when(
    gi_star_numeric > 1.96  ~ "Hotspot",
    gi_star_numeric < -1.96 ~ "Coldspot",
    TRUE                    ~ "Neutral"
  ))

# Count hotspots and coldspots per local authority
authority_summary <- data_with_gi %>%
  filter(gi_class != "Neutral") %>%
  group_by(Local.authority, gi_class) %>%
  summarise(count = n(), .groups = "drop")

print(authority_summary)
#table
library(knitr)
library(kableExtra)

authority_summary %>%
  kable(
    caption = "Number of Hotspot and Coldspot Areas by Local Authority",
    col.names = c("Local Authority", "Type", "Number of Areas"),
    align = "lcl"
  ) %>%
  kable_styling(
    full_width = FALSE,
    bootstrap_options = c("striped", "hover", "condensed")
  )

#visiaulisation
library(ggplot2)

hotspot_plot <- authority_summary %>%
  filter(gi_class == "Hotspot") %>%
  ggplot(aes(x = reorder(Local.authority, -count), y = count, fill = gi_class)) +
  geom_bar(stat = "identity") +
  labs(title = "Hotspots by Local Authority",
       x = "Local Authority",
       y = "Number of Hotspots") +
  scale_fill_manual(values = c("Hotspot" = "red")) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), plot.title = element_text(hjust = 0.5))

print(hotspot_plot)


coldspot_plot <- authority_summary %>%
  filter(gi_class == "Coldspot") %>%
  ggplot(aes(x = reorder(Local.authority, -count), y = count, fill = gi_class)) +
  geom_bar(stat = "identity") +
  labs(title = "Coldspots by Local Authority",
       x = "Local Authority",
       y = "Number of Coldspots") +
  scale_fill_manual(values = c("Coldspot" = "#1F77B4")) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), plot.title = element_text(hjust = 0.5))

print(coldspot_plot)






