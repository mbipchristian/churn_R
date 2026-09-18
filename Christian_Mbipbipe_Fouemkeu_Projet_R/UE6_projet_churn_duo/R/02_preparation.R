library(tidyverse)
library(lubridate)
library(arrow)

# =========================================================
# 1. FEATURE ENGINEERING : AGRÉGATION DES TRANSACTIONS
# Objectif : construire des indicateurs comportementaux par client
#
# Variables créées :
# - n_transactions : nombre total de transactions du client
# - total_amount   : somme totale des montants transactés par client
# - avg_amount     : moyenne des montants transactés par client
# - max_amount     : montant maximum transacté par client
# - min_amount     : montant minimum transacté par client
# - n_refunds      : nombre de transactions avec montant négatif
# - recency_days   : nombre de jours depuis la dernière transaction
# - tenure_active  : durée entre première et dernière transaction (ancienneté active)
# =========================================================

transactions_agg <- transactions %>%
  group_by(customer_id) %>%
  summarise(
    n_transactions = n(),
    total_amount = sum(amount),
    avg_amount = mean(amount),
    max_amount = max(amount),
    min_amount = min(amount),
    
    n_refunds = sum(amount < 0),
    
    recency_days = as.numeric(Sys.Date() - max(date)),
    tenure_active = as.numeric(max(date) - min(date))
  )

# =========================================================
# 2. FEATURE ENGINEERING : FRÉQUENCE MENSUELLE
# Objectif : mesurer la régularité d’activité des clients
#
# Variables créées :
# - month             : mois de la transaction (date arrondie au mois)
# - n                 : nombre de transactions par client et par mois
# - avg_monthly_txn   : moyenne mensuelle de transactions
#                       (indicateur de fréquence d’achat)
# =========================================================

transactions_freq <- transactions %>%
  mutate(month = floor_date(date, "month")) %>%
  count(customer_id, month) %>%
  group_by(customer_id) %>%
  summarise(avg_monthly_txn = mean(n))

# =========================================================
# 3. FEATURE ENGINEERING : CANAL DOMINANT
# Objectif : identifier le canal préféré du client
#
# Variables créées :
# - channel : canal le plus utilisé (web, mobile, agence, etc.)
# - n       : nombre d’utilisations de ce canal
#             (correspond au maximum pour ce client)
# =========================================================

channel_mode <- transactions %>%
  count(customer_id, channel) %>%
  group_by(customer_id) %>%
  slice_max(n, n = 1, with_ties = FALSE)

# =========================================================
# 4. FEATURE ENGINEERING : ANCIENNETE DU CLIENT
# Variable créée : 
# - tenure_simple : nombre de jours depuis l'enrégistrement du client
# =========================================================

clients_tenure <- clients %>%
  mutate(tenure_simple = as.numeric(Sys.Date() - signup_date))%>%
  select(-signup_date)                        # Suppression de la variable signup_date
  
# =========================================================
# 5. CONSTRUCTION DU DATASET FINAL
# Objectif : consolider toutes les informations client
#
# Données combinées :
# - clients             : informations de base client
# - transactions_agg    : variables comportementales et financières
# - transactions_freq   : fréquence d’activité
# - channel_mode        : canal dominant
# - regions_mapping     : enrichissement géographique
# - labels              : variable cible (ex : churn, fraude, etc.)
#
# Remarque :
# - left_join garantit que tous les clients sont conservés,
#   même sans transactions (valeurs NA possibles)
# =========================================================

dataset <- clients_tenure %>%
  left_join(transactions_agg, by = "customer_id") %>%
  left_join(transactions_freq, by = "customer_id") %>%
  left_join(channel_mode, by = "customer_id") %>%
  left_join(regions_mapping, by = "region") %>%
  left_join(labels, by = "customer_id")

# Vérifions s'il ya des valeures NA
dataset[dataset == ""] <- NA
print(colSums(is.na(dataset)))
glimpse(dataset)

# Exportation des dataset clean : 
write_parquet(dataset, "data/processed/dataset_clean.parquet")