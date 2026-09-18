import streamlit as st
import pandas as pd
import plotly.express as px

# Charger les données exportées depuis R
df = pd.read_parquet("C:\\Users\\ebam\\Desktop\\MES_DOSSIERS\\UTT\\R\\projet_R\\UE6_projet_churn_duo\\data\\processed\\dataset_clean.parquet")

st.title("Dashboard Clients (Streamlit)")

# KPI
total_clients = len(df)
active_clients = (df["is_active"] == "yes").sum()

col1, col2 = st.columns(2)
col1.metric("Clients totaux", total_clients)
col2.metric("Clients actifs", active_clients)

# Filtre
region = st.selectbox("Choisir une région", ["Toutes"] + list(df["region_group"].dropna().unique()))

if region != "Toutes":
    df = df[df["region_group"] == region]

# Graphique
fig = px.histogram(
    df,
    x="recency_days",
    color="is_active",
    title="Récence des clients"
)

st.plotly_chart(fig)