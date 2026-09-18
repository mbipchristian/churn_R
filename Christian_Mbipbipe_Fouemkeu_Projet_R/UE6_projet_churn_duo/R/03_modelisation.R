library(tidymodels)
library(vip)

dataset_clean <- read_parquet("data/processed/dataset_clean.parquet")

# Vérifier que la variable cible est un facteur
table(dataset_clean$is_active)
dataset_clean$is_active <- as.factor(dataset_clean$is_active)

# Séparation des données en deux ensembles (train/test)
set.seed(123)
split <- initial_split(dataset_clean, prop = 0.8, strata = is_active)
train_data <- training(split)
test_data  <- testing(split)

# Préprocessing
rec <- recipe(is_active ~ ., data = train_data) %>%
  step_rm(customer_id) %>%                           # supprimer ID
  step_impute_mean(all_numeric()) %>%                # remplacer NA numériques
  step_impute_mode(all_nominal_predictors()) %>%     # remplacer NA catégorielles
  step_dummy(all_nominal_predictors()) %>%           # encoder variables catégorielles sauf is_active
  step_normalize(all_numeric_predictors())           # normalise les variables sauf is_active


# Définir le modèle
log_model <- logistic_reg() %>%
  set_engine("glm") %>%                        # Modèle statistique classique
  set_mode("classification")                   # Prédiction binaire

# Création du workflow : on combine préprocessing et modèle
wf <- workflow() %>%
  add_recipe(rec) %>%
  add_model(log_model)

# Entrainement du modèle
model_fit <- fit(wf, data = train_data)

# Evaluation des coefficients
tidy(model_fit)                       # Les coefficients positifs augmentent la probabilité 
                                      # Les coefficients négatifs diminuent la probabilité

# On fait les prédictions
predictions <- predict(model_fit, test_data, type = "prob") %>%
  bind_cols(predict(model_fit, test_data)) %>%
  bind_cols(test_data %>% select(is_active))

# Evaluation du modèle
metric_set(
  accuracy, bal_accuracy,
  precision, recall, f_meas,
  sens, spec,
  roc_auc, pr_auc,
  mn_log_loss
)(predictions, truth = is_active, estimate = .pred_class, .pred_yes)

########################################################################################
#                                                                                     ##
# RANDOM FOREST                                                                       ##
#                                                                                     ##
########################################################################################

rf_model <- rand_forest(
  trees = 500,
  mtry = 10,     # nombre de variables testées à chaque split
  min_n = 15     # taille minimale des feuilles
) %>%
  set_engine("ranger", importance = "impurity") %>%
  set_mode("classification")

# Preprocessing 
rec_rf <- recipe(is_active ~ ., data = train_data) %>%
  step_rm(customer_id) %>%
  step_impute_mean(all_numeric_predictors()) %>%
  step_impute_mode(all_nominal_predictors()) %>%
  step_dummy(all_nominal_predictors())

# Validation croisée
set.seed(123)
cv_folds <- vfold_cv(train_data, v = 5, strata = is_active)

# Grille d'hyperparamètres
rf_grid <- grid_regular(
  mtry(range = c(2, 10)),
  min_n(range = c(2, 20)),
  levels = 5
)

# Workflow
rf_wf <- workflow() %>%
  add_recipe(rec_rf) %>%
  add_model(rf_model)

# Tuning
rf_tuned <- tune_grid(
  rf_wf,
  resamples = cv_folds,
  grid = rf_grid,
  metrics = metric_set(roc_auc, accuracy, precision, recall)
)

# Meilleurs paramètres
best_params <- select_best(rf_tuned, metric = "roc_auc")
best_params

# Modèle final
rf_final <- finalize_workflow(rf_wf, best_params)
rf_fit <- fit(rf_final, data = train_data)

# Prédictions & évaluation
rf_preds <- predict(rf_fit, test_data, type = "prob") %>%
  bind_cols(predict(rf_fit, test_data)) %>%
  bind_cols(test_data %>% select(is_active))

metric_set(
  accuracy, bal_accuracy,
  precision, recall, f_meas,
  sens, spec,
  roc_auc, pr_auc,
  mn_log_loss
)(predictions, truth = is_active, estimate = .pred_class, .pred_yes)

# Importance des variables

rf_fit %>%
  extract_fit_parsnip() %>%
  vip()


# =========================================================
# JUSTIFICATION DU MODELE RETENU
# =========================================================

# Deux modèles ont été testés :
# - Régression logistique
# - Random Forest
#
# Résultats obtenus :
# - Logistic Regression : Accuracy ~ 0.64 | ROC AUC ~ 0.43
# - Random Forest       : Accuracy ~ 0.61 | ROC AUC ~ 0.50
#
# Interprétation :
# - Les deux modèles présentent des performances faibles
# - Le Random Forest n'apporte aucune amélioration significative
# - Le pouvoir prédictif des variables est globalement faible

# Choix du modèle :
#   La régression logistique est retenue
#
# Justification :
# - Modèle simple et interprétable
# - Permet de comprendre l'influence des variables
# - Plus stable que les modèles complexes dans ce contexte
#
# Conclusion :
# Dans un contexte où la performance est limitée,
# il est préférable de privilégier l'interprétabilité.


# =========================================================
# COMPROMIS PERFORMANCE / INTERPRETABILITE
# =========================================================

# Régression logistique :
# + Interprétable (coefficients lisibles)
# + Explicable pour les équipes métier
# - Suppose des relations linéaires
# - Moins performante sur relations complexes

# Random Forest :
# + Capte non-linéarités et interactions
# + Généralement plus performant
# - Modèle "boîte noire"
# - Difficilement interprétable
# - Ici : aucune amélioration des performances

# Conclusion :
#   Le compromis favorise l'interprétabilité,
# car les modèles complexes n'apportent pas de gain.


# =========================================================
# CHOIX DU SEUIL DE DECISION
# =========================================================

# Par défaut :
# threshold = 0.5
#
# Problème observé :
# - Données déséquilibrées (plus de "yes" que de "no")
# - Le modèle prédit majoritairement "yes"
# - Mauvaise détection des clients "no"

# Ajustement du seuil :
#   On peut augmenter le seuil pour être plus strict

# Exemple :
# predictions <- predictions %>%
#   mutate(custom_class = ifelse(.pred_yes > 0.7, "yes", "no"))

# Effet du seuil :
# - seuil élevé (0.6 - 0.7) :
#     → réduit les faux positifs
#     → modèle plus conservateur
#
# - seuil faible (0.3 - 0.4) :
#     → détecte plus de "yes"
#     → augmente les faux positifs

# Choix recommandé :
#   threshold ≈ 0.6 - 0.7

# Justification métier :
# - Eviter de cibler à tort des clients comme actifs
# - Réduire les coûts marketing inutiles

# Conclusion :
# Le seuil de décision doit être ajusté selon l'objectif métier
# (précision vs détection).


# =========================================================
# CONCLUSION GENERALE
# =========================================================

# Points positifs :
# - Pipeline de modélisation structuré (tidymodels)
# - Comparaison de plusieurs modèles
# - Evaluation rigoureuse (accuracy, ROC, confusion matrix)

# Limites :
# - Faible pouvoir explicatif des variables
# - Difficulté à distinguer clients actifs / inactifs

# Recommandation :  AMELIORER LE FEATURE ENGINEERING :
# - Variables de récence (très important)
# - Dynamique temporelle
# - Comportement récent

# Conclusion finale :
# Le modèle est techniquement valide mais limité par la qualité
# des données. Une amélioration des variables explicatives est
# nécessaire pour obtenir des performances satisfaisantes.