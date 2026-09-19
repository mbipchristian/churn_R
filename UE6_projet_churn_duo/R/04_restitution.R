library(ggplot2)

# Distribution de la cible (déséquilibre)
dataset_clean %>%
  count(is_active) %>%
  ggplot(aes(x = is_active, y = n, fill = is_active)) +
  geom_col() +
  labs(
    title = "Distribution des clients actifs vs inactifs",
    x = "Statut",
    y = "Nombre de clients"
  ) +
  theme_minimal()

# Recency vs activité
dataset_clean %>%
  ggplot(aes(x = recency_days, fill = is_active)) +
  geom_histogram(bins = 40, alpha = 0.6, position = "identity") +
  labs(
    title = "Récence vs activité client",
    x = "Jours depuis dernière transaction",
    y = "Nombre de clients"
  ) +
  theme_minimal()

# Fréquence / engagement
dataset_clean %>%
  ggplot(aes(x = avg_monthly_txn, fill = is_active)) +
  geom_density(alpha = 0.5) +
  labs(
    title = "Fréquence mensuelle vs activité",
    x = "Transactions mensuelles moyennes",
    y = "Densité"
  ) +
  theme_minimal()

# Segmentation simple (2D business-ready)
dataset_clean %>%
  ggplot(aes(x = recency_days, y = avg_monthly_txn, color = is_active)) +
  geom_point(alpha = 0.6) +
  labs(
    title = "Segmentation clients (Récence vs Fréquence)",
    x = "Récence (jours)",
    y = "Fréquence mensuelle"
  ) +
  theme_minimal()