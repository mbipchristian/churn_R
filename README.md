# Rapport Décisionnel — Prédiction de l'Activité Client (Churn)
Voici le lien vers le rapport html : [rapport décisionnel](rapport_decisionnel.html)
## 🎯 Synthèse

Projet de prédiction de l'activité client (actif/inactif) via régression logistique et Random Forest. **Performances limitées** (ROC AUC < 0,50) : faible pouvoir prédictif des variables disponibles. Priorité : enrichir le feature engineering avant tout déploiement.

## 📊 Données

5 sources jointes sur `customer_id` / `region` :
- `customers.csv` — données socio-démographiques
- `transactions.csv` — historique transactionnel
- `labels.csv` — cible binaire `is_active`
- `regions_mapping.csv` — enrichissement géographique
- `channels_mapping.json` — mapping des canaux

**Déséquilibre des classes : 64/36** (actifs/inactifs), non traité (pas de SMOTE ni pondération).

**Traitements qualité** : gestion des valeurs manquantes, typage des dates, imputation (moyenne/mode), encodage dummy, normalisation.

## 🔧 Feature Engineering

10 variables construites : `n_transactions`, `total_amount`, `avg/max/min_amount`, `n_refunds`, `recency_days`, `tenure_active`, `avg_monthly_txn`, `channel`, `tenure_simple`, `region_group`.

## 📈 Résultats

| Métrique | Régression Logistique | Random Forest |
|---|---|---|
| Accuracy | 63,9 % | 61,0 % |
| ROC AUC | **0,427** ⚠️ | 0,50 |
| Recall | 13,3 % | 20,0 % |
| F1-Score | 20,8 % | 25,0 % |

⚠️ **ROC AUC < 0,50** = performance sous le niveau du hasard → manque de signal discriminant, pas un bug.

Seules variables significatives (régression logistique) : **âge** (β=0,238) et **opt-in marketing** (β=0,213). Les variables transactionnelles ne sont pas significatives.

## ✅ Modèle retenu : Régression Logistique

Choisie malgré des performances équivalentes au Random Forest, pour son **interprétabilité** (coefficients lisibles, explicabilité métier).

## 🎚️ Seuil de décision

- Seuil par défaut (0,5) → biais vers la classe majoritaire, recall très faible
- **Seuil recommandé : 0,65** → réduit les faux positifs, adapté à des ressources marketing limitées

```r
predictions <- predictions %>%
  mutate(custom_class = ifelse(.pred_yes >= 0.65, "yes", "no"))
```

## ⚠️ Limites principales

1. ROC AUC sous le hasard (critique)
2. Déséquilibre de classes non traité
3. Absence de variables temporelles fines (tendances 30/60/90j)
4. Tuning Random Forest inefficace (`tune()` non utilisé)
5. Pas de courbe ROC / matrice de confusion
6. Pas de pipeline de réentraînement

## 🚀 Pistes d'amélioration prioritaires

- **Score RFM** (Récence × Fréquence × Montant)
- **Indicateurs de tendance temporelle** (30/60/90 jours)
- **SMOTE** ou pondération de classe (`themis`)
- **Modèles alternatifs** : XGBoost, LightGBM, régression logistique + SMOTE
- Correction du tuning Random Forest (`mtry`, `min_n` avec `tune()`)
- Dashboard Shiny/Streamlit pour simuler l'impact du seuil
- Réentraînement mensuel automatisé
