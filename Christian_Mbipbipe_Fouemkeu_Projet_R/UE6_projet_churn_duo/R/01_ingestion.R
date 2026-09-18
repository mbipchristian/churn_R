library(tidyverse)             
library(jsonlite)

# chargement de données brutes

clients <- read.csv("data/raw/customers.csv")
transactions <- read.csv("data/raw/transactions.csv")
labels <- read.csv("data/raw/labels.csv")
regions_mapping <- read.csv("data/raw/regions_mapping.csv")

channels_mapping <- fromJSON("data/raw/channels_mapping.json") # Car channels_mapping est un json et non un CSV

channels_mapping <- jsonlite::flatten(channels_mapping) # Pour aplatir les données afin de mieux les exploiter

# Fonction de controle de la qualité des données

check_data_quality <- function(df, name) {
  
  cat("\n====================\n")
  cat("Dataset :", name, "\n")
  cat("====================\n\n")
  
  # Aperçu
  cat("🔹 Aperçu :\n")
  print(head(df))
  
  # Types
  cat("\n🔹 Structure :\n")
  print(str(df))
  
  # Valeurs manquantes
  cat("\n🔹 Valeurs manquantes :\n")
  print(colSums(is.na(df)))
  
  # Doublons (si id_client existe)
  if ("id_client" %in% colnames(df)) {
    cat("\n🔹 Doublons sur id_client :\n")
    print(sum(duplicated(df$id_client)))
  }
  
  cat("\n\n")
}

#   Remplacer les "" par des NA :
clean_empty_to_na <- function(df){
  df[df == ""] <- NA
  return(df)
}

# Application de la fonction de remplacement des vides par NA
clients <- clean_empty_to_na(clients)
transactions <- clean_empty_to_na(transactions)
labels <- clean_empty_to_na(labels)
regions_mapping <- clean_empty_to_na(regions_mapping)
channels_mapping <- clean_empty_to_na(channels_mapping)

# Application de la fonction de controle de qualité à toutes mes tables

check_data_quality(clients, "clients")
check_data_quality(transactions, "transactions")
check_data_quality(regions_mapping, "regions_mapping")
check_data_quality(labels, "labels")
check_data_quality(channels_mapping, "channels_mapping")


# La variable signup_date de "clients" est de type "chaine de caractère", nous devons donc changer ce type en date : 
clients$signup_date <- as.Date(clients$signup_date)

# La variable date de "transactions" est de type "chaine de caractère", nous devons donc changer ce type en date : 
transactions$date <- as.Date(transactions$date)

# Suppression des valeurs manquantes dans la table clients : 
clients <- clients %>% drop_na()

# Vérifier si les changements ont bien été pris en compte : 
class(clients$signup_date)
class(transactions$date)
print(colSums(is.na(clients)))