###############################################################################
# Humanitarian Communication Analysis
# Based on Chouliaraki's framework of post-humanitarian communication
# Author: Irene Chen
# Date: May 2, 2025
###############################################################################

# ===================================
#   1.0 SETUP & DATA LOADING
# ===================================

# Load required packages
library(tidyverse)
library(tidytext)
library(quanteda)
library(quanteda.textplots)
library(syuzhet)
library(widyr)
library(ggplot2)
library(ggraph)
library(igraph)
library(topicmodels)

# Load data
activities_data <- read_csv("data/globalgiving_activities.csv")

# Uncomment to load saved results
# cooc_results <- readRDS("results/cooc_results.rds")
# agency_counts <- readRDS("results/agency_counts.rds")
# sentiment_tokens <- readRDS("results/sentiment_tokens.rds")
# lda_model <- readRDS("results/lda_model.rds")

# ===================================
#   2.0 THEMATIC PARTITIONING
# ===================================

# Group sector codes into meaningful themes
activities_grouped <- activities_data %>%
  # Add doc_id at the beginning to ensure it's available throughout
  mutate(doc_id = row_number()) %>%
  mutate(theme = case_when(
    # Emergency Response & Immediate Relief
    sector_code %in% c("M99", "K30", "Q71") ~ "Emergency Relief",
    
    # Empowerment & Education
    sector_code %in% c("S30", "U99", "G80", "N60", "Q35") ~ "Empowerment & Education",
    
    # Protection & Vulnerable Groups
    sector_code %in% c("P30", "I70", "R24", "R26") ~ "Protection & Rights",
    
    # Health & Wellbeing
    sector_code %in% c("E99", "E40", "F99") ~ "Health & Wellbeing",
    
    # Other categories we're not focusing on in primary analysis
    sector_code %in% c("L99", "C32", "C99", "D99", "B99", "K99", "I99", "A99") ~ "Other",
    
    TRUE ~ "Uncategorized"
  ))

# Check counts by theme (optional)
theme_counts <- activities_grouped %>%
  group_by(theme) %>%
  summarise(count = n()) %>%
  arrange(desc(count))

# print(theme_counts)

# Filter to our themes of interest
activities_selected <- activities_grouped %>%
  filter(theme != "Other" & theme != "Uncategorized")

# Verify selected themes (optional)
selected_counts <- activities_selected %>%
  group_by(theme) %>%
  summarise(count = n(),
            sector_codes = paste(unique(sector_code), collapse = ", "))

# print(selected_counts)

# ===================================
#   3.0 TEXT PREPROCESSING
# ===================================

# ---------------------
# 3.1 Tokenize the text
# ---------------------
activities_selected <- activities_selected %>%
  mutate(year = year(start_date))

# Tokenize descriptions
tokens_df <- activities_selected %>% 
  select(doc_id, theme, year, description) %>%
  unnest_tokens(word, description) %>%
  anti_join(stop_words) %>%
  filter(!str_detect(word, "^[0-9]+$"))  # Remove numbers

# -------------------------------
# 3.2 Examine Most Frequent Words
# -------------------------------
word_counts <- tokens_df %>%
  count(theme, word) %>%
  group_by(theme) %>%
  mutate(proportion = n / sum(n)) %>%
  ungroup()

# Get top words by theme
top_words <- word_counts %>%
  group_by(theme) %>%
  slice_max(order_by = n, n = 20) %>%
  ungroup()

# Plot top words by theme
plot_top_words <- ggplot(top_words, aes(x = reorder(word, n), y = n, fill = theme)) +
  geom_col() +
  facet_wrap(~theme, scales = "free_y") +
  coord_flip() +
  labs(title = "Most Frequent Words by Theme",
       x = "Word",
       y = "Frequency") +
  theme_minimal() +
  scale_fill_brewer(palette = "Set1")

print(plot_top_words)
ggsave("figures/top_words_by_theme.png", plot_top_words, width = 10, height = 8)

# =================================== 
#   4.0 SENTIMENT ANALYSIS
# ===================================

# Get NRC sentiment scores
nrc_sentiment <- get_sentiments("nrc")

# Join tokens with sentiment lexicon
sentiment_tokens <- tokens_df %>%
  inner_join(nrc_sentiment) %>%
  count(theme, sentiment) %>%
  group_by(theme) %>%
  mutate(proportion = n / sum(n)) %>%
  ungroup()

# Plot sentiment by theme
plot_sentiment <- ggplot(sentiment_tokens %>% 
                           filter(sentiment %in% c("positive", "negative", "trust", "fear", "joy", "sadness", "anger")),
                         aes(x = sentiment, y = proportion, fill = theme)) +
  geom_col(position = "dodge") +
  labs(title = "Sentiment Distribution by Theme",
       x = "Sentiment",
       y = "Proportion") +
  theme_minimal() +
  scale_fill_brewer(palette = "Set1")

print(plot_sentiment)
ggsave("figures/sentiment_by_theme.png", plot_sentiment, width = 10, height = 6)

# Save sentiment analysis
saveRDS(sentiment_tokens, "results/sentiment_tokens.rds")

# ===================================
#   5.0 AGENCY ANALYSIS
# ===================================

#--------- 
# 5.1. Define agency dictionaries
#---------
agency_dict <- list(
  "Victim Terms" = c(
    "victim", "victims", "vulnerable", "poor", "needy", "helpless", "suffering",
    "desperate", "displaced", "homeless", "hungry", "sick", "wounded", "afflicted",
    "impoverished", "marginalized", "disadvantaged", "affected"
  ),
  
  "Beneficiary Terms" = c(
    "beneficiary", "beneficiaries", "recipient", "recipients", "community", 
    "communities", "population", "populations", "family", "families", 
    "people", "individual", "individuals", "resident", "residents"
  ),
  
  "Agent Terms" = c(
    "partner", "partners", "leader", "leaders", "participant", "participants",
    "entrepreneur", "entrepreneurs", "student", "students", "activist", "activists",
    "volunteer", "volunteers", "teacher", "teachers", "farmer", "farmers",
    "artisan", "artisans", "provider", "providers", "changemaker", "changemakers"
  )
)

#--------- 
# 5.2. Count dictionary terms
#---------
count_dict_terms <- function(tokens_dataframe, dictionaries) {
  # First check if doc_id exists in the dataframe
  if(!"doc_id" %in% colnames(tokens_dataframe)) {
    stop("doc_id column not found in tokens dataframe")
  }
  
  results <- tibble(
    theme = character(),
    dictionary = character(),
    count = integer(),
    proportion = numeric()
  )
  
  for (theme_name in unique(tokens_dataframe$theme)) {
    # Filter tokens for this theme
    theme_tokens <- tokens_dataframe %>% 
      filter(theme == theme_name)
    
    # Count total unique documents for this theme
    total_docs <- theme_tokens %>% 
      pull(doc_id) %>% 
      unique() %>% 
      length()
    
    for (dict_name in names(dictionaries)) {
      dict_words <- dictionaries[[dict_name]]
      
      # Count documents containing these terms
      # Using group_by + filter + summarize approach to avoid distinct() issues
      doc_count <- theme_tokens %>%
        filter(word %in% dict_words) %>%
        group_by(doc_id) %>%
        summarize(has_term = TRUE, .groups = "drop") %>%
        nrow()
      
      results <- results %>% bind_rows(
        tibble(
          theme = theme_name,
          dictionary = dict_name,
          count = doc_count,
          proportion = doc_count / total_docs
        )
      )
    }
  }
  
  return(results)
}

# Count agency terms
agency_counts <- count_dict_terms(tokens_df, agency_dict)

# Plot agency term proportions
plot_agency <- ggplot(agency_counts, aes(x = dictionary, y = proportion, fill = theme)) +
  geom_col(position = "dodge") +
  labs(title = "Agency Terminology by Theme",
       x = "Term Category",
       y = "Proportion of Documents",
       fill = "Theme") +
  theme_minimal() +
  scale_fill_brewer(palette = "Set1")

print(plot_agency)
ggsave("figures/agency_by_theme.png", plot_agency, width = 10, height = 6)

# Save agency analysis
saveRDS(agency_counts, "results/agency_counts.rds")

#--------- 
# 5.3 Detailed term-level analysis for agency
#---------
agency_term_counts <- tokens_df %>%
  mutate(term_type = case_when(
    word %in% agency_dict[["Victim Terms"]] ~ "Victim Terms",
    word %in% agency_dict[["Beneficiary Terms"]] ~ "Beneficiary Terms",
    word %in% agency_dict[["Agent Terms"]] ~ "Agent Terms",
    TRUE ~ "Other"
  )) %>%
  filter(term_type != "Other") %>%
  count(theme, term_type, word)

top_agency_terms <- agency_term_counts %>%
  group_by(theme, term_type) %>%
  slice_max(order_by = n, n = 5) %>%
  ungroup()

plot_top_agency_terms <- ggplot(top_agency_terms, 
                                aes(x = reorder(word, n), y = n, fill = theme)) +
  geom_col() +
  facet_grid(term_type ~ theme, scales = "free") +
  coord_flip() +
  labs(title = "Top Agency Terms by Theme and Category",
       x = "Term",
       y = "Count",
       fill = "Theme") +
  theme_minimal() +
  scale_fill_brewer(palette = "Set1")

print(plot_top_agency_terms)
ggsave("figures/top_agency_terms.png", plot_top_agency_terms, width = 12, height = 9)

# =================================== 
#   6.0 CO-OCCURRENCE ANALYSIS
# ===================================

#--------- 
# 6.1. Create co-occurrence function
#---------
create_fast_cooccurrence <- function(tokens_df, window_size = 5, min_count = 3) {
  # Identify key terms we're interested in
  key_terms <- c("help", "support", "empower", "children", "women", "community")
  
  # Initialize result structure
  result <- tibble(
    theme = character(),
    key_term = character(),
    associated_term = character(),
    count = integer()
  )
  
  # Process each theme separately
  for(t in unique(tokens_df$theme)) {
    # Filter tokens for this theme
    theme_tokens <- tokens_df %>% filter(theme == t)
    
    # Process by document for memory efficiency
    for(doc in unique(theme_tokens$doc_id)) {
      # Get words in order
      doc_words <- theme_tokens %>% 
        filter(doc_id == doc) %>% 
        pull(word)
      
      # Skip if too few words
      if(length(doc_words) < 2) next
      
      # Find co-occurrences for key terms only
      key_indices <- which(doc_words %in% key_terms)
      
      for(idx in key_indices) {
        key_term <- doc_words[idx]
        
        # Find context window
        start_idx <- max(1, idx - window_size)
        end_idx <- min(length(doc_words), idx + window_size)
        
        # Get context words (excluding the key term itself)
        context_indices <- setdiff(start_idx:end_idx, idx)
        context_words <- doc_words[context_indices]
        
        # Count each co-occurrence
        for(context_word in context_words) {
          result <- result %>% add_row(
            theme = t,
            key_term = key_term,
            associated_term = context_word,
            count = 1
          )
        }
      }
    }
  }
  
  # Aggregate counts
  result <- result %>%
    group_by(theme, key_term, associated_term) %>%
    summarise(count = sum(count), .groups = "drop") %>%
    filter(count >= min_count) %>%  # Filter for significant associations
    arrange(theme, key_term, desc(count))
  
  return(result)
}

#--------- 
# 6.2. Apply co-occurrence analysis
#---------
cooc_results <- create_fast_cooccurrence(tokens_df, window_size = 5, min_count = 3)

# Get top associations
top_associations <- cooc_results %>%
  group_by(theme, key_term) %>%
  slice_head(n = 10) %>%
  ungroup()

# Visualization function
visualize_term_cooccurrence <- function(cooc_results, term, top_n = 10) {
  # Check if the term exists in the results
  if(!(term %in% unique(cooc_results$key_term))) {
    # If term doesn't exist, return a warning message
    warning(paste0("Term '", term, "' not found in co-occurrence results"))
    return(NULL)
  }
  
  term_viz <- cooc_results %>%
    filter(key_term == term) %>%
    group_by(theme) %>%
    slice_max(order_by = count, n = top_n) %>%
    ungroup()
  
  # Check if we have data for all themes
  if(length(unique(term_viz$theme)) < 4) {
    # Add missing themes with dummy data to prevent facet error
    all_themes <- c("Emergency Relief", "Empowerment & Education", 
                    "Health & Wellbeing", "Protection & Rights")
    missing_themes <- setdiff(all_themes, unique(term_viz$theme))
    
    for(t in missing_themes) {
      term_viz <- term_viz %>%
        add_row(
          key_term = term,
          theme = t,
          associated_term = "NO DATA",
          count = 0
        )
    }
  }
  
  # Create visualization
  plot <- ggplot(term_viz, 
                 aes(x = reorder(associated_term, count), y = count, fill = theme)) +
    geom_col() +
    facet_wrap(~theme, scales = "free_y") +
    coord_flip() +
    labs(title = paste('Words Most Associated with "', term, '" by Theme', sep=''),
         x = "Associated Word",
         y = "Co-occurrence Count",
         fill = "Theme") +
    theme_minimal() +
    scale_fill_brewer(palette = "Set1")
  
  return(plot)
}

#--------- 
# 6.3. Visualize co-occurrences for key terms
#---------
# Plot help associations
help_assoc <- top_associations %>% 
  filter(key_term == "help") %>%
  group_by(theme) %>%
  slice_head(n = 5)

if(nrow(help_assoc) > 0) {
  plot_help <- ggplot(help_assoc, aes(x = reorder(associated_term, count), 
                                      y = count, fill = theme)) +
    geom_col() +
    facet_wrap(~theme, scales = "free_y") +
    coord_flip() +
    labs(title = 'Words Most Associated with "help" by Theme',
         x = "Associated Word",
         y = "Co-occurrence Count",
         fill = "Theme") +
    theme_minimal() +
    scale_fill_brewer(palette = "Set1")
  
  print(plot_help)
  ggsave("figures/help_cooccurrences.png", plot_help, width = 10, height = 6)
}

# Generate community co-occurrence plot
community_plot <- visualize_term_cooccurrence(cooc_results, "community", top_n = 8)
print(community_plot)
ggsave("figures/community_cooccurrences.png", community_plot, width = 10, height = 6)

# Generate women co-occurrence plot
women_plot <- visualize_term_cooccurrence(cooc_results, "women", top_n = 8)
print(women_plot)
ggsave("figures/women_cooccurrences.png", women_plot, width = 10, height = 6)

# Save co-occurrence results
saveRDS(cooc_results, "results/cooc_results.rds")

# =================================== 
#   7.0 TOPIC MODELING
# ===================================

#--------- 
# 7.1. Create document-term matrix
#---------
dtm <- tokens_df %>%
  count(doc_id, word) %>%
  cast_dtm(doc_id, word, n)

#--------- 
# 7.2. Run LDA
#---------
set.seed(123)
k <- 8  # Number of topics
lda_model <- LDA(dtm, k = k, method = "Gibbs", 
                 control = list(seed = 123, iter = 1000, verbose = 25))

#--------- 
# 7.3. Extract and analyze topics
#---------
# Extract top terms for each topic
top_terms <- terms(lda_model, 15)
topic_terms_df <- as.data.frame(top_terms)
colnames(topic_terms_df) <- paste0("Topic_", 1:k)

# Print topic terms(optional)
# print(topic_terms_df)

# Extract document-topic probabilities
doc_topics <- as.data.frame(posterior(lda_model)$topics)
doc_topics$doc_id <- as.integer(rownames(doc_topics))

# Add theme information
doc_topics <- doc_topics %>%
  left_join(activities_selected %>% select(doc_id, theme))

# Calculate average topic proportions by theme
theme_topics <- doc_topics %>%
  group_by(theme) %>%
  summarise(across(1:k, mean)) %>%
  pivot_longer(cols = 2:(k+1), 
               names_to = "topic", 
               values_to = "proportion")

# Visualize topic distribution by theme
plot_topic_dist <- ggplot(theme_topics, aes(x = topic, y = proportion, fill = theme)) +
  geom_col(position = "dodge") +
  labs(title = "Topic Distribution by Theme",
       x = "Topic",
       y = "Average Proportion",
       fill = "Theme") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_fill_brewer(palette = "Set1")

print(plot_topic_dist)
ggsave("figures/topic_distribution.png", plot_topic_dist, width = 10, height = 6)

# Save topic modeling results
saveRDS(lda_model, "results/lda_model.rds")

# ===================================
#   8.0 VECTOR SPACE ANALYSIS
# ===================================

#--------- 
# 8.1. Create TF-IDF matrix
#---------
library(tm)

if("DocumentTermMatrix" %in% class(dtm)) {
  dtm_tm <- dtm
} else {
  dtm_tm <- as.DocumentTermMatrix(dtm, weighting = weightTf)
}

# Apply TF-IDF weighting
tfidf <- weightTfIdf(dtm_tm)
tfidf_matrix <- as.matrix(tfidf)

# Remove sparse terms (appears in <1% of documents)
tfidf_matrix <- tfidf_matrix[, colSums(tfidf_matrix > 0) > nrow(tfidf_matrix) * 0.01]

# Check for zero variance columns and remove them
col_vars <- apply(tfidf_matrix, 2, var)
tfidf_matrix <- tfidf_matrix[, col_vars > 0]

#--------- 
# 8.2. Apply PCA
#---------
# Sample if dataset is too large
if(nrow(tfidf_matrix) > 5000) {
  set.seed(123)
  sample_indices <- sample(1:nrow(tfidf_matrix), 5000)
  tfidf_matrix_sample <- tfidf_matrix[sample_indices,]
  sample_doc_ids <- as.integer(rownames(tfidf_matrix)[sample_indices])
} else {
  tfidf_matrix_sample <- tfidf_matrix
  sample_doc_ids <- as.integer(rownames(tfidf_matrix))
}

# Run PCA
pca_result <- prcomp(tfidf_matrix_sample, scale. = TRUE)

# Create dataframe for visualization
pca_df <- data.frame(
  PC1 = pca_result$x[,1],
  PC2 = pca_result$x[,2],
  doc_id = sample_doc_ids
)

# Add theme information
pca_df <- pca_df %>%
  left_join(activities_selected %>% select(doc_id, theme))

#--------- 
# 8.3. Cluster documents
#---------
set.seed(123)
k_clusters <- 6
kmeans_result <- kmeans(pca_df[,c("PC1", "PC2")], centers = k_clusters)
pca_df$cluster <- as.factor(kmeans_result$cluster)

# Visualize clusters
plot_clusters <- ggplot(pca_df, aes(x = PC1, y = PC2, color = theme, shape = cluster)) +
  geom_point(alpha = 0.6) +
  labs(title = "Document Clusters by Theme",
       x = "Principal Component 1",
       y = "Principal Component 2",
       color = "Theme",
       shape = "Cluster") +
  theme_minimal() +
  scale_color_brewer(palette = "Set1")

print(plot_clusters)
ggsave("figures/document_clusters.png", plot_clusters, width = 10, height = 8)

#--------- 
# 8.4. Examine cluster composition
#---------

# Examine cluster composition by theme
cluster_theme_composition <- pca_df %>%
  group_by(cluster, theme) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(cluster) %>%
  mutate(proportion = count / sum(count)) %>%
  ungroup()

plot_cluster_comp <- ggplot(cluster_theme_composition, 
                            aes(x = as.factor(cluster), y = proportion, fill = theme)) +
  geom_col() +
  labs(title = "Theme Composition of Each Cluster",
       x = "Cluster",
       y = "Proportion",
       fill = "Theme") +
  theme_minimal() +
  scale_fill_brewer(palette = "Set1")

print(plot_cluster_comp)
ggsave("figures/cluster_composition.png", plot_cluster_comp, width = 10, height = 6)

#--------- 
# 8.5. Analyze PCA loadings
#---------
if(exists("pca_result")) {
  # Get loadings
  loadings <- as.data.frame(pca_result$rotation)
  
  # For PC1
  pc1_top_pos <- rownames(loadings)[order(loadings$PC1, decreasing = TRUE)[1:15]]
  pc1_top_neg <- rownames(loadings)[order(loadings$PC1)[1:15]]
  
  # For PC2
  pc2_top_pos <- rownames(loadings)[order(loadings$PC2, decreasing = TRUE)[1:15]]
  pc2_top_neg <- rownames(loadings)[order(loadings$PC2)[1:15]]
  
  # Create dataframe for plotting
  pc_words <- bind_rows(
    tibble(word = pc1_top_pos, dimension = "PC1", direction = "positive", loading = loadings[pc1_top_pos, "PC1"]),
    tibble(word = pc1_top_neg, dimension = "PC1", direction = "negative", loading = loadings[pc1_top_neg, "PC1"]),
    tibble(word = pc2_top_pos, dimension = "PC2", direction = "positive", loading = loadings[pc2_top_pos, "PC2"]),
    tibble(word = pc2_top_neg, dimension = "PC2", direction = "negative", loading = loadings[pc2_top_neg, "PC2"])
  )
  
  # Plot
  plot_pca_loadings <- ggplot(pc_words, aes(x = reorder(word, abs(loading)), y = loading, fill = direction)) +
    geom_col() +
    facet_wrap(~dimension, scales = "free") +
    coord_flip() +
    labs(title = "Top Words Contributing to Principal Components",
         x = "Word",
         y = "Loading",
         fill = "Direction") +
    theme_minimal() +
    scale_fill_manual(values = c("positive" = "blue", "negative" = "red"))
  
  print(plot_pca_loadings)
  ggsave("figures/pca_loadings.png", plot_pca_loadings, width = 10, height = 8)
}

# =================================== 
#   9.0 TEMPORAL ANALYSIS
# ===================================

#--------- 
# 9.1. Analyze agency term evolution
#---------
analyze_agency_evolution <- function(tokens_dataframe, dictionaries) {
  # Check if doc_id, year, theme exist
  if(!all(c("doc_id", "year", "theme") %in% colnames(tokens_dataframe))) {
    stop("Missing required columns in tokens dataframe")
  }
  
  results <- tibble(
    theme = character(),
    year = integer(),
    dictionary = character(),
    count = integer(),
    proportion = numeric()
  )
  
  for (theme_name in unique(tokens_dataframe$theme)) {
    for (year_val in unique(tokens_dataframe$year)) {
      
      # Filter tokens for this theme-year
      theme_year_tokens <- tokens_dataframe %>%
        filter(theme == theme_name, year == year_val)
      
      # Skip if no tokens (avoiding errors)
      if (nrow(theme_year_tokens) == 0) next
      
      # Total documents in this theme-year
      total_docs <- theme_year_tokens %>%
        pull(doc_id) %>%
        unique() %>%
        length()
      
      for (dict_name in names(dictionaries)) {
        dict_words <- dictionaries[[dict_name]]
        
        # Documents containing terms from this dictionary
        doc_count <- theme_year_tokens %>%
          filter(word %in% dict_words) %>%
          group_by(doc_id) %>%
          summarize(has_term = TRUE, .groups = "drop") %>%
          nrow()
        
        results <- results %>% bind_rows(
          tibble(
            theme = theme_name,
            year = year_val,
            dictionary = dict_name,
            count = doc_count,
            proportion = doc_count / total_docs
          )
        )
      }
    }
  }
  
  return(results)
}

# Run the analysis
agency_evolution <- analyze_agency_evolution(tokens_df, agency_dict)

# Plot agency evolution
plot_agency_time <- ggplot(agency_evolution, aes(x = year, y = proportion, color = dictionary)) +
  geom_line(size = 1) +
  facet_wrap(~theme, scales = "free_y") +
  labs(
    title = "Agency Attribution Patterns Over Time",
    x = "Year",
    y = "Proportion of Documents Containing Term",
    color = "Agency Type"
  ) +
  theme_minimal() +
  scale_color_manual(values = c(
    "Beneficiary Terms" = "green",
    "Victim Terms" = "red",
    "Agent Terms" = "skyblue"
  )) +
  theme(text = element_text(size = 12))

print(plot_agency_time)
ggsave("figures/agency_time_evolution.png", plot_agency_time, width = 12, height = 8)

# Save temporal analysis results
saveRDS(agency_evolution, "results/agency_evolution.rds")

# ===================================
#   END OF ANALYSIS
# ===================================