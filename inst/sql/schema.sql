-- Nemeton PostgreSQL/PostGIS Schema
-- ADR-002: niveau plateforme (multi-utilisateurs, requetes spatiales)

-- Extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Schema nemeton
-- ============================================================
CREATE SCHEMA IF NOT EXISTS nemeton;

-- ============================================================
-- Users & Roles
-- ============================================================
CREATE TABLE IF NOT EXISTS nemeton.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  external_id TEXT UNIQUE,           -- ID du fournisseur OAuth (sub claim)
  provider TEXT DEFAULT 'local',     -- keycloak, google, github, agentconnect
  email TEXT UNIQUE,
  name TEXT NOT NULL,
  preferred_language TEXT DEFAULT 'fr',
  profile_key TEXT DEFAULT 'profil_citoyen',  -- cle NMT du profil acteur
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS nemeton.user_roles (
  user_id UUID REFERENCES nemeton.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,                -- admin, gestionnaire, lecteur
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, role)
);

-- ============================================================
-- Projects
-- ============================================================
CREATE TABLE IF NOT EXISTS nemeton.projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT UNIQUE NOT NULL,   -- ex: 20260327_144122_ilgd
  owner_id UUID REFERENCES nemeton.users(id),
  name TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'draft',       -- draft, downloading, computing, completed, error
  ndp_level INTEGER DEFAULT 0,
  commune_code TEXT,
  commune_name TEXT,
  department_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_projects_owner ON nemeton.projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_projects_commune ON nemeton.projects(commune_code);
CREATE INDEX IF NOT EXISTS idx_projects_department ON nemeton.projects(department_code);

-- ============================================================
-- Parcels (geometries spatiales)
-- ============================================================
CREATE TABLE IF NOT EXISTS nemeton.parcels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES nemeton.projects(id) ON DELETE CASCADE,
  nemeton_id TEXT,                   -- identifiant interne nemeton
  geo_parcelle TEXT,                 -- reference cadastrale
  section TEXT,
  numero TEXT,
  contenance NUMERIC,
  geometry GEOMETRY(MultiPolygon, 2154),  -- Lambert-93
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_parcels_project ON nemeton.parcels(project_id);
CREATE INDEX IF NOT EXISTS idx_parcels_geometry ON nemeton.parcels USING GIST(geometry);

-- ============================================================
-- Indicators (31 indicateurs par parcelle)
-- ============================================================
CREATE TABLE IF NOT EXISTS nemeton.indicators (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parcel_id UUID REFERENCES nemeton.parcels(id) ON DELETE CASCADE,
  project_id UUID REFERENCES nemeton.projects(id) ON DELETE CASCADE,
  -- 31 indicateurs (valeurs brutes)
  carbon_biomass NUMERIC,
  carbon_ndvi NUMERIC,
  biodiversity_protection NUMERIC,
  biodiversity_structure NUMERIC,
  biodiversity_connectivity NUMERIC,
  water_network NUMERIC,
  water_wetlands NUMERIC,
  water_twi NUMERIC,
  air_coverage NUMERIC,
  air_quality NUMERIC,
  soil_fertility NUMERIC,
  soil_erosion NUMERIC,
  landscape_edge NUMERIC,
  landscape_fragmentation NUMERIC,
  temporal_age NUMERIC,
  temporal_change NUMERIC,
  risk_fire NUMERIC,
  risk_storm NUMERIC,
  risk_drought NUMERIC,
  risk_browsing NUMERIC,
  social_accessibility NUMERIC,
  social_proximity NUMERIC,
  social_trails NUMERIC,
  productive_volume NUMERIC,
  productive_station NUMERIC,
  productive_quality NUMERIC,
  energy_fuelwood NUMERIC,
  energy_avoidance NUMERIC,
  naturalness_distance NUMERIC,
  naturalness_continuity NUMERIC,
  naturalness_composite NUMERIC,
  -- 12 familles (scores normalises 0-100)
  family_B NUMERIC,
  family_C NUMERIC,
  family_W NUMERIC,
  family_A NUMERIC,
  family_F NUMERIC,
  family_L NUMERIC,
  family_T NUMERIC,
  family_R NUMERIC,
  family_S NUMERIC,
  family_P NUMERIC,
  family_E NUMERIC,
  family_N NUMERIC,
  -- Metadata
  computed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_indicators_project ON nemeton.indicators(project_id);
CREATE INDEX IF NOT EXISTS idx_indicators_parcel ON nemeton.indicators(parcel_id);

-- ============================================================
-- Comments (perspectives IA)
-- ============================================================
CREATE TABLE IF NOT EXISTS nemeton.comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES nemeton.projects(id) ON DELETE CASCADE,
  type TEXT NOT NULL,                -- synthesis, family_B, family_C, etc.
  profile_key TEXT,                  -- profil acteur utilise
  content TEXT,
  language TEXT DEFAULT 'fr',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_project ON nemeton.comments(project_id);
