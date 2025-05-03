# Post-Humanitarian Communication Analysis

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

This repository contains computational text analysis examining the evolution of beneficiary representation in humanitarian communication across different sectors. The analysis operationalizes and empirically tests Lilie Chouliaraki's theoretical framework on humanitarian communication styles using a large corpus of project descriptions from the GlobalGiving platform.

## Theoretical Framework

Chouliaraki's (2010) seminal work "Post-humanitarianism: Humanitarian communication beyond a politics of pity" identifies a historical trajectory in how Western humanitarian organizations frame beneficiaries in their communication. She argues that humanitarian appeals have evolved through three distinct phases:

1. **"Shock effect" appeals** that rely on graphic depictions of suffering to provoke guilt and indignation, establishing maximal distance between spectator and sufferer
2. **"Positive image" appeals** that reject victimization imagery in favor of representing beneficiaries as dignified agents with capacity for self-determination
3. **"Post-humanitarian" communication** that breaks with both approaches by emphasizing technologized action, low-intensity emotions, and reflexive awareness of representation itself

This evolution reflects broader tensions in the relationship between humanitarianism and politics. Traditional appeals rely on "grand emotions" (guilt, indignation, empathy) to motivate action, but these emotional registers have faced increasing challenges in sustaining audience engagement in contemporary media environments, leading to what Boltanski terms a "crisis of pity" (Boltanski, 1999).

Our study translates Chouliaraki's theoretical constructs into measurable linguistic patterns to examine whether and how these communicative styles manifest across different humanitarian sectors. Through computational analysis of a large corpus (25,000+ project descriptions), we empirically investigate whether her theoretical model accurately describes contemporary humanitarian discourse and how different sectors navigate the tension between representing vulnerability and empowerment.

## Data

The dataset comprises approximately 25,000 project descriptions from the GlobalGiving platform spanning 2010-2022. These projects represent diverse humanitarian sectors categorized into four primary themes based on sector codes:

| Theme | Sector Codes | Description |
|-------|-------------|-------------|
| Emergency Relief | M99, K30, Q71 | Disaster relief, food security, refugee support |
| Empowerment & Education | S30, U99, G80, N60, Q35 | Skills development, technology education, disability support |
| Protection & Rights | P30, I70, R24, R26 | Child protection, domestic violence, women's education, LGBTQ support |
| Health & Wellbeing | E99, E40, F99 | Healthcare provision, mental health services, menstrual supplies |

Projects falling outside these categories were classified as "Other" or "Uncategorized" and excluded from the primary analysis to maintain thematic clarity.

## Methodology

This project employs multiple computational text analysis methods to examine patterns of beneficiary representation:

### Text Preprocessing
- Tokenization and cleaning of project descriptions
- Removal of stopwords and numbers
- Creation of document-term matrix

### Dictionary-Based Analyses
- **Word Frequency Analysis**: Identifying distinctive terminology across humanitarian themes
- **Sentiment Analysis**: Measuring emotional valence using the NRC emotion lexicon (Mohammad & Turney, 2013)
- **Agency Analysis**: Custom dictionaries measuring the distribution of "victim," "beneficiary," and "agent" terminology based on Chouliaraki's framework

### Unsupervised Learning
- **Co-occurrence Analysis**: Mapping semantic relationships between key terms using a sliding window approach
- **Topic Modeling**: Extracting latent thematic structures using Latent Dirichlet Allocation (Blei et al., 2003)
- **Vector Space Analysis**: Using TF-IDF weighting, Principal Component Analysis, and k-means clustering to identify latent dimensions of variation in the corpus

### Temporal Analysis
- Tracking agency attribution patterns over time (2010-2022)
- Examining evolution of sentiment profiles by humanitarian theme

## Key Findings

1. **Distinctive Agency Profiles**: Different humanitarian themes employ distinctive linguistic strategies to represent beneficiaries. Emergency Relief more frequently positions beneficiaries as passive recipients (high use of "victim" and "beneficiary" terms), while Empowerment & Education more commonly represents them as active agents.

2. **Persistent Vulnerability Framing**: Even empowerment-focused communication continues to rely heavily on vulnerability framing, with "Beneficiary" and "Victim" terms consistently outweighing "Agent" terms across all themes.

3. **Multidimensional Discursive Space**: Vector space analysis reveals that humanitarian discourse operates in a two-dimensional space defined by development vs. emergency orientation (PC1) and entrepreneurial vs. institutional approaches (PC2).

4. **Sector-Specific Evolution**: Temporal analysis shows different evolutionary trajectories across humanitarian themes rather than a uniform progression from vulnerability to agency framing, with Health & Wellbeing showing the most consistent pattern of increasing beneficiary-oriented language.

5. **Strategic Tension**: The strategic blending of vulnerability and agency framing, particularly in Empowerment & Education communications, suggests organizations navigate a fundamental tension between establishing need (to justify intervention) and emphasizing capacity (to promote dignity).

## Repository Structure

```
post-humanitarian-text-analysis/
├── data/                      # Data directory
│   └── globalgiving_activities.csv  # Primary dataset
├── scripts/                   # Code scripts
│   └── main-analysis.R        # Main analysis script
├── results/                   # Saved analysis results
│   ├── agency_counts.rds      # Agency term analysis
│   ├── cooc_results.rds       # Co-occurrence analysis
│   ├── sentiment_tokens.rds   # Sentiment analysis
│   ├── lda_model.rds          # Topic modeling results
│   └── agency_evolution.rds   # Temporal analysis results
├── figures/                   # Generated visualizations
└── README.md                  # Project documentation
```

## Usage

### Prerequisites

The analysis requires the following R packages:
```r
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
library(tm)
```

### Running the Analysis

1. Clone this repository:
```bash
git clone https://github.com/yourusername/post-humanitarian-text-analysis.git
cd post-humanitarian-text-analysis
```

2. Create necessary directories if they don't exist:
```bash
mkdir -p data results figures
```

3. Place the `globalgiving_activities.csv` file in the `data` directory.

4. Run the analysis script:
```bash
Rscript analysis.R
```

5. Results will be saved in the `results` directory, and visualizations in the `figures` directory.

## Output Files

The script generates the following outputs:

### Visualizations (in `figures/` directory)
- `top_words_by_theme.png`: Most frequent words by humanitarian theme
- `sentiment_by_theme.png`: Sentiment distribution across themes
- `agency_by_theme.png`: Agency term distribution across themes
- `top_agency_terms.png`: Top agent/victim/beneficiary terms by theme
- `help_cooccurrences.png`: Terms co-occurring with "help" across themes
- `community_cooccurrences.png`: Terms co-occurring with "community"
- `women_cooccurrences.png`: Terms co-occurring with "women"
- `topic_distribution.png`: LDA topic distribution by theme
- `document_clusters.png`: PCA projection of documents with cluster assignment
- `cluster_composition.png`: Theme composition of each cluster
- `pca_loadings.png`: Terms contributing to principal components
- `agency_time_evolution.png`: Temporal evolution of agency term usage

### Analysis Results (in `results/` directory)
- `sentiment_tokens.rds`: NRC sentiment scores for each theme
- `agency_counts.rds`: Agency term distribution by theme
- `cooc_results.rds`: Co-occurrence matrix for key terms
- `lda_model.rds`: LDA topic model (k=8)
- `agency_evolution.rds`: Temporal agency attribution patterns

## Citation

If you use this code or analysis in your research, please cite:

```
Chen, I. (2025). Evolution of Agency in Humanitarian Communication: Text Analysis of GlobalGiving Project Descriptions. 
Georgetown University, McCourt School of Public Policy.
```

And the original theoretical framework:

```
Chouliaraki, L. (2010). Post-humanitarianism: Humanitarian communication beyond a politics of pity. 
International Journal of Cultural Studies, 13(2), 107-126. https://doi.org/10.1177/1367877909356720
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. The MIT License is included to permit others to freely use, modify, and distribute this code while maintaining attribution to the original author.

## Acknowledgments

- This analysis was conducted as the final project for the "Text As Data: Computational Linguistics" course at Georgetown University's McCourt School of Public Policy.
- Thanks to Professor Nejla Asimovic for guidance throughout this project.
- The GlobalGiving platform for making project data available for research purposes.
- Lilie Chouliaraki for the theoretical framework that guided this analysis.

## References

Blei, D. M., Ng, A. Y., & Jordan, M. I. (2003). Latent Dirichlet Allocation. Journal of Machine Learning Research, 3, 993-1022.

Boltanski, L. (1999). Distant Suffering: Morality, Media and Politics. Cambridge University Press.

Chouliaraki, L. (2010). Post-humanitarianism: Humanitarian communication beyond a politics of pity. International Journal of Cultural Studies, 13(2), 107-126.

Mohammad, S. M., & Turney, P. D. (2013). Crowdsourcing a word–emotion association lexicon. Computational Intelligence, 29(3), 436-465.
