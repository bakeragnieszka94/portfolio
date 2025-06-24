############################
######Chi-squared test#####
##########################

#Simple analisis do crime depend on location 
glimpse(data_crime)
#Packages
library(dplyr)
library(ggplot2)
library(ggpubr)   
#1.Does Specific Type of Crime Depend on Local Authority?
#Chi-squared test of independence 
# Filter out County Durham for the Chi-squared test
data_crime_filtered <- data_crime %>%
  filter(Local.authority != "County Durham")
#Chi-squared test
tbl1_filtered <- table(data_crime_filtered$Crime.type, data_crime_filtered$Local.authority)
chisq_result_filtered <- chisq.test(tbl1_filtered)
chisq_result_filtered
#Table for report
chi_summary <- data.frame(
  Statistic = "Chi-squared",
  Value = round(chisq_result_filtered$statistic, 2),
  DF = chisq_result_filtered$parameter,
  p_value = format.pval(chisq_result_filtered$p.value, digits = 3, eps = .001)
)
# formatted table
chi_summary %>%
  kable(caption = "Summary of Chi-squared Test Results",
        col.names = c("Test", "Chi-squared Value", "Degrees of Freedom", "p-value")) %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed"))
#save table
write.csv(chi_summary, "chi_squared_summary.csv", row.names = FALSE)

# Components of the Chi-squared test
observed_filtered <- chisq_result_filtered$observed
expected_filtered <- chisq_result_filtered$expected
std_resid_filtered <- chisq_result_filtered$stdres
contrib_filtered <- (std_resid_filtered)^2
contrib_pct_filtered <- round(100 * contrib_filtered / sum(contrib_filtered), 2)

#result table in long format
result_table_filtered <- as.data.frame(as.table(observed_filtered)) %>%
  rename(CrimeType = Var1, LocalAuthority = Var2, Observed = Freq) %>%
  mutate(Expected = as.vector(expected_filtered),
         StdResid = round(as.vector(std_resid_filtered), 2),
         Contribution = round(as.vector(contrib_pct_filtered), 2))

# view few rows
head(result_table_filtered)

# Save table as CSV 
write.csv(result_table_filtered, "chi_squared_filtered_output.csv", row.names = FALSE)
#knitr table
# Use the full result table
result_table_filtered %>%
  arrange(desc(Contribution)) %>%
  kable(digits = 2,
        caption = "All Local Authority and Crime Type: Observed vs Expected Counts with Chi-squared Contributions",
        col.names = c("Crime Type", "Local Authority", "Observed", "Expected", "Standardised Residual", "Contribution (%)")) %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed")) %>%
  scroll_box(height = "600px")


#Does Specific Type of Crime Depend on Local Authority: Visualization
ggplot(data_crime, aes(x = Local.authority, fill = Crime.type)) +
  geom_bar(position = "dodge") + 
  coord_flip() +
  labs(title = "Proportion of Crime Types by Local Authority",
       y = "Proportion", x = "Local Authority") +
  theme_minimal()


#change colors to fit better for report theam 
report_colors <- c("#01B8AA", "#FFB81C", "#F2C111", "#D9D9D6", "#E64A19", "#8E44AD", 
                   "#1F77B4", "#FF7F0E", "#2CA02C", "#9467BD", "#6A5ACD", "#FF6347", 
                   "#3CB371", "#D2691E")

# Plot with the updated color vector
ggplot(data_crime, aes(x = Local.authority, fill = Crime.type)) +
  geom_bar(position = "dodge") + 
  labs(title = "Proportion of Crime Types by Local Authority",
       y = "Proportion", x = "Local Authority") +
  scale_fill_manual(values = report_colors) +  
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1), # Rotate x-axis labels for readability
    plot.title = element_text(hjust = 0.5)  # Center title
  )
# Filter out County Durham
data_crime_filtered <- data_crime %>%
  filter(Local.authority != "County Durham")
# Plot with the updated color vector
ggplot(data_crime_filtered, aes(x = Local.authority, fill = Crime.type)) +
  geom_bar(position = "dodge") + 
  labs(title = "Crime Types by Local Authority",
       y = "Proportion", x = "Local Authority") +
  scale_fill_manual(values = report_colors) +  
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1), # Rotate x-axis labels for readability
    plot.title = element_text(hjust = 0.5)  # Center title
  )
#Highlight Significant Residuals Only (get most meaningful differences)
#distribution of residuals
ggplot(result_table_filtered, aes(x = StdResid)) +
  geom_histogram(binwidth = 0.5, fill = "lightblue", color = "black") +
  labs(title = "Distribution of Standardized Residuals", x = "Standardized Residual", y = "Frequency") +
  theme_minimal()

#table for significiant only
library(knitr)
library(kableExtra)

# Filter significant results and format the table
result_table_filtered %>%
  filter(abs(StdResid) >= 2 | Contribution >= 2) %>%
  arrange(desc(Contribution)) %>%
  kable(
    digits = 2,
    caption = "Key Local Authority and Crime Type Combinations Contributing Most to the Chi-squared Statistic",
    col.names = c("Crime Type", "Local Authority", "Observed", "Expected", "Standardised Residual", "Contribution (%)")
  ) %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed")) %>%
  save_kable("significant_chi_squared_table.html")

#save as csv
write.csv(result_table_filtered  %>%
            filter(abs(StdResid) >= 2 | Contribution >= 2) %>%
            arrange(desc(Contribution)), "key_contributions_table.csv", row.names = FALSE)


#2.Number of Crimes by Local Authority
data_crime_filtered %>%
  count(Local.authority) %>%
  ggplot(aes(x = reorder(Local.authority, n), y = n)) +
  geom_col(fill = "#1F77B4") +
  coord_flip() +
  labs(title = "Total Number of Crimes per Local Authority",
       x = "Local Authority", y = "Number of Crimes") +
  theme_minimal()

#3.Number of Crimes by LSOA
data_crime_filtered %>%
  count(LSOA.name) %>%
  top_n(30, n) %>%
  ggplot(aes(x = reorder(LSOA.name, n), y = n)) +
  geom_col(fill = "#1F77B4") +
  coord_flip() +
  labs(title = "Top 30 LSOAs by Total Number of Crimes",
       x = "LSOA", y = "Number of Crimes") +
  theme_minimal()


