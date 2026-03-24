-- ============================================================================
-- ICONS — Cartografia do Contencioso Constitucional
-- Schema Completo — Supabase (PostgreSQL)
-- Instituto Constituição Aberta · PROJUS · Coord. Damares Medina
-- ============================================================================

-- ============================================================================
-- 1. TIPOS ENUMERADOS
-- ============================================================================

CREATE TYPE tipo_artigo AS ENUM ('CF', 'ADCT');
CREATE TYPE tipo_paragrafo AS ENUM ('unico', 'numerado');
CREATE TYPE orgao_julgador AS ENUM ('P', '1T', '2T', 'mono');
CREATE TYPE tipo_bloco AS ENUM ('concentrado', 'repercussao_geral', 'correlato', 'sumula');
CREATE TYPE status_jurisprudencial AS ENUM (
    'reafirmacao', 'oscilacao', 'reversao', 'fragmentacao', 'nao_classificado'
);
CREATE TYPE tipo_sumula AS ENUM ('vinculante', 'comum');

-- ============================================================================
-- 2. TABELAS ESTRUTURAIS — Topografia da Constituição Federal
-- ============================================================================

-- 9 Títulos (placas tectônicas)
CREATE TABLE cf_titulos (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_romano TEXT    NOT NULL,
    numero_int    INTEGER NOT NULL UNIQUE,
    denominacao   TEXT    NOT NULL,
    cor_hex       CHAR(7) NOT NULL,
    ordem         INTEGER NOT NULL UNIQUE
);

-- 33 Capítulos
CREATE TABLE cf_capitulos (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titulo_id     BIGINT  NOT NULL REFERENCES cf_titulos(id) ON DELETE CASCADE,
    numero_romano TEXT    NOT NULL,
    numero_int    INTEGER NOT NULL,
    denominacao   TEXT    NOT NULL,
    ordem         INTEGER NOT NULL,
    UNIQUE (titulo_id, numero_int)
);

-- 50 Seções
CREATE TABLE cf_secoes (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    capitulo_id   BIGINT  NOT NULL REFERENCES cf_capitulos(id) ON DELETE CASCADE,
    titulo_id     BIGINT  NOT NULL REFERENCES cf_titulos(id) ON DELETE CASCADE,
    numero_romano TEXT    NOT NULL,
    numero_int    INTEGER NOT NULL,
    denominacao   TEXT    NOT NULL,
    ordem         INTEGER NOT NULL,
    UNIQUE (capitulo_id, numero_int)
);

-- 5 Subseções (raras)
CREATE TABLE cf_subsecoes (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    secao_id      BIGINT  NOT NULL REFERENCES cf_secoes(id) ON DELETE CASCADE,
    numero_romano TEXT    NOT NULL,
    numero_int    INTEGER NOT NULL,
    denominacao   TEXT    NOT NULL,
    ordem         INTEGER NOT NULL,
    UNIQUE (secao_id, numero_int)
);

-- 250 Artigos CF + 138 ADCT
CREATE TABLE cf_artigos (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero          INTEGER NOT NULL,
    numero_texto    TEXT    NOT NULL,       -- "5º", "1º", "100"
    caput           TEXT    NOT NULL,
    tipo            tipo_artigo NOT NULL DEFAULT 'CF',
    titulo_id       BIGINT  REFERENCES cf_titulos(id) ON DELETE SET NULL,
    capitulo_id     BIGINT  REFERENCES cf_capitulos(id) ON DELETE SET NULL,
    secao_id        BIGINT  REFERENCES cf_secoes(id) ON DELETE SET NULL,
    subsecao_id     BIGINT  REFERENCES cf_subsecoes(id) ON DELETE SET NULL,
    ordem           INTEGER NOT NULL,
    vigente         BOOLEAN NOT NULL DEFAULT TRUE,
    alterado_por_ec INTEGER[],             -- números das ECs que alteraram
    UNIQUE (numero, tipo)
);

-- Parágrafos de cada artigo
CREATE TABLE cf_paragrafos (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    artigo_id     BIGINT  NOT NULL REFERENCES cf_artigos(id) ON DELETE CASCADE,
    tipo          tipo_paragrafo NOT NULL,
    numero        INTEGER,                 -- NULL para parágrafo único
    numero_texto  TEXT    NOT NULL,         -- "único", "1º", "2º"
    texto         TEXT    NOT NULL,
    ordem         INTEGER NOT NULL,
    UNIQUE (artigo_id, tipo, numero)
);

-- Incisos (do caput ou de parágrafo)
CREATE TABLE cf_incisos (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    artigo_id       BIGINT  NOT NULL REFERENCES cf_artigos(id) ON DELETE CASCADE,
    paragrafo_id    BIGINT  REFERENCES cf_paragrafos(id) ON DELETE CASCADE,
    numero_romano   TEXT    NOT NULL,       -- "I", "II", "LXXVIII"
    numero_int      INTEGER NOT NULL,
    texto           TEXT    NOT NULL,
    ordem           INTEGER NOT NULL
);

-- Alíneas (de incisos)
CREATE TABLE cf_alineas (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inciso_id BIGINT NOT NULL REFERENCES cf_incisos(id) ON DELETE CASCADE,
    letra     CHAR(1) NOT NULL,            -- 'a', 'b', 'c'...
    texto     TEXT    NOT NULL,
    ordem     INTEGER NOT NULL,
    UNIQUE (inciso_id, letra)
);

-- ============================================================================
-- 3. TABELAS DE JURISPRUDÊNCIA
-- ============================================================================

-- Decisões únicas do STF
CREATE TABLE stf_decisoes (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    classe          TEXT    NOT NULL,       -- ADI, ADPF, RE, HC...
    numero          INTEGER NOT NULL,
    classe_numero   TEXT    NOT NULL UNIQUE,-- "ADI 4.650"
    relator         TEXT,
    data_julgamento DATE,
    data_dje        DATE,
    orgao_julgador  orgao_julgador,
    ementa          TEXT,
    integra_url     TEXT,
    downloaded      BOOLEAN NOT NULL DEFAULT FALSE
);

-- VÍNCULO central: dispositivo <-> decisão
-- Cada linha = +1 no índice de decidibilidade
CREATE TABLE cf_vinculos (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Âncora constitucional (artigo_id sempre obrigatório)
    artigo_id               BIGINT  NOT NULL REFERENCES cf_artigos(id) ON DELETE CASCADE,
    paragrafo_id            BIGINT  REFERENCES cf_paragrafos(id) ON DELETE SET NULL,
    inciso_id               BIGINT  REFERENCES cf_incisos(id) ON DELETE SET NULL,
    alinea_id               BIGINT  REFERENCES cf_alineas(id) ON DELETE SET NULL,
    -- Decisão
    decisao_id              BIGINT  NOT NULL REFERENCES stf_decisoes(id) ON DELETE CASCADE,
    -- Hierarquia de exibição
    tipo_bloco              tipo_bloco NOT NULL,
    -- Análise de estabilidade
    status_jurisprudencial  status_jurisprudencial NOT NULL DEFAULT 'nao_classificado',
    -- Texto de contexto do documento original
    texto_contexto          TEXT,
    ordem                   INTEGER NOT NULL DEFAULT 0,
    -- Evitar vínculo duplicado: mesma decisão no mesmo dispositivo exato
    UNIQUE (artigo_id, paragrafo_id, inciso_id, alinea_id, decisao_id)
);

-- Súmulas
CREATE TABLE stf_sumulas (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero    INTEGER NOT NULL,
    tipo      tipo_sumula NOT NULL,
    enunciado TEXT    NOT NULL,
    vigente   BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (numero, tipo)
);

-- Emendas Constitucionais
CREATE TABLE ec_emendas (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero           INTEGER NOT NULL UNIQUE,
    data             DATE    NOT NULL,
    ementa           TEXT,
    artigos_alterados INTEGER[]
);

-- ============================================================================
-- 4. ÍNDICES PARA PERFORMANCE
-- ============================================================================

-- Navegação hierárquica
CREATE INDEX idx_capitulos_titulo    ON cf_capitulos(titulo_id);
CREATE INDEX idx_secoes_capitulo     ON cf_secoes(capitulo_id);
CREATE INDEX idx_secoes_titulo       ON cf_secoes(titulo_id);
CREATE INDEX idx_subsecoes_secao     ON cf_subsecoes(secao_id);
CREATE INDEX idx_artigos_titulo      ON cf_artigos(titulo_id);
CREATE INDEX idx_artigos_capitulo    ON cf_artigos(capitulo_id);
CREATE INDEX idx_artigos_secao       ON cf_artigos(secao_id);
CREATE INDEX idx_artigos_tipo        ON cf_artigos(tipo);
CREATE INDEX idx_artigos_ordem       ON cf_artigos(ordem);

-- Hierarquia interna dos dispositivos
CREATE INDEX idx_paragrafos_artigo   ON cf_paragrafos(artigo_id);
CREATE INDEX idx_incisos_artigo      ON cf_incisos(artigo_id);
CREATE INDEX idx_incisos_paragrafo   ON cf_incisos(paragrafo_id);
CREATE INDEX idx_alineas_inciso      ON cf_alineas(inciso_id);

-- Vínculos — queries frequentes
CREATE INDEX idx_vinculos_artigo     ON cf_vinculos(artigo_id);
CREATE INDEX idx_vinculos_decisao    ON cf_vinculos(decisao_id);
CREATE INDEX idx_vinculos_tipo_bloco ON cf_vinculos(tipo_bloco);
CREATE INDEX idx_vinculos_status     ON cf_vinculos(status_jurisprudencial);

-- Decisões
CREATE INDEX idx_decisoes_classe     ON stf_decisoes(classe);
CREATE INDEX idx_decisoes_julgamento ON stf_decisoes(data_julgamento);

-- ============================================================================
-- 5. VIEWS ANALÍTICAS
-- ============================================================================

-- Índice de decidibilidade por artigo
CREATE OR REPLACE VIEW v_decidibilidade_artigo AS
SELECT
    a.id                    AS artigo_id,
    a.numero                AS artigo_numero,
    a.numero_texto          AS artigo_texto,
    a.tipo                  AS artigo_tipo,
    a.titulo_id,
    COUNT(v.id)             AS total_vinculos,
    COUNT(v.id) FILTER (WHERE v.tipo_bloco = 'concentrado')         AS concentrado,
    COUNT(v.id) FILTER (WHERE v.tipo_bloco = 'repercussao_geral')   AS repercussao_geral,
    COUNT(v.id) FILTER (WHERE v.tipo_bloco = 'correlato')           AS correlato,
    COUNT(v.id) FILTER (WHERE v.tipo_bloco = 'sumula')              AS sumula
FROM cf_artigos a
LEFT JOIN cf_vinculos v ON v.artigo_id = a.id
GROUP BY a.id, a.numero, a.numero_texto, a.tipo, a.titulo_id;

-- Índice de decidibilidade por título (para o sismógrafo)
CREATE OR REPLACE VIEW v_decidibilidade_titulo AS
SELECT
    t.id              AS titulo_id,
    t.numero_romano,
    t.denominacao,
    t.cor_hex,
    COUNT(v.id)       AS total_vinculos,
    COUNT(DISTINCT v.decisao_id) AS decisoes_unicas,
    COUNT(DISTINCT v.artigo_id)  AS artigos_com_vinculos
FROM cf_titulos t
LEFT JOIN cf_artigos a ON a.titulo_id = t.id
LEFT JOIN cf_vinculos v ON v.artigo_id = a.id
GROUP BY t.id, t.numero_romano, t.denominacao, t.cor_hex;

-- Série temporal por dispositivo (para o sismógrafo)
CREATE OR REPLACE VIEW v_serie_temporal AS
SELECT
    v.artigo_id,
    a.numero_texto      AS artigo_texto,
    a.titulo_id,
    EXTRACT(YEAR FROM d.data_julgamento)::INTEGER AS ano,
    COUNT(v.id)         AS total_vinculos
FROM cf_vinculos v
JOIN cf_artigos a    ON a.id = v.artigo_id
JOIN stf_decisoes d  ON d.id = v.decisao_id
WHERE d.data_julgamento IS NOT NULL
GROUP BY v.artigo_id, a.numero_texto, a.titulo_id, EXTRACT(YEAR FROM d.data_julgamento);

-- Estabilidade jurisprudencial por artigo
CREATE OR REPLACE VIEW v_estabilidade AS
SELECT
    a.id                AS artigo_id,
    a.numero_texto      AS artigo_texto,
    a.titulo_id,
    COUNT(v.id)         AS total_vinculos,
    COUNT(v.id) FILTER (WHERE v.status_jurisprudencial = 'reafirmacao')      AS reafirmacao,
    COUNT(v.id) FILTER (WHERE v.status_jurisprudencial = 'oscilacao')        AS oscilacao,
    COUNT(v.id) FILTER (WHERE v.status_jurisprudencial = 'reversao')         AS reversao,
    COUNT(v.id) FILTER (WHERE v.status_jurisprudencial = 'fragmentacao')     AS fragmentacao,
    COUNT(v.id) FILTER (WHERE v.status_jurisprudencial = 'nao_classificado') AS nao_classificado
FROM cf_artigos a
LEFT JOIN cf_vinculos v ON v.artigo_id = a.id
GROUP BY a.id, a.numero_texto, a.titulo_id;

-- ============================================================================
-- 6. ROW LEVEL SECURITY (Supabase)
-- ============================================================================

ALTER TABLE cf_titulos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_capitulos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_secoes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_subsecoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_artigos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_paragrafos ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_incisos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_alineas    ENABLE ROW LEVEL SECURITY;
ALTER TABLE stf_decisoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE cf_vinculos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE stf_sumulas   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ec_emendas    ENABLE ROW LEVEL SECURITY;

-- Leitura pública (dados constitucionais são públicos)
CREATE POLICY "Leitura pública" ON cf_titulos    FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_capitulos  FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_secoes     FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_subsecoes  FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_artigos    FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_paragrafos FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_incisos    FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_alineas    FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON stf_decisoes  FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON cf_vinculos   FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON stf_sumulas   FOR SELECT USING (true);
CREATE POLICY "Leitura pública" ON ec_emendas    FOR SELECT USING (true);

-- Escrita apenas via service_role (scripts de seed/importação)
CREATE POLICY "Escrita service_role" ON cf_titulos    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_capitulos  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_secoes     FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_subsecoes  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_artigos    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_paragrafos FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_incisos    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_alineas    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON stf_decisoes  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON cf_vinculos   FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON stf_sumulas   FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Escrita service_role" ON ec_emendas    FOR ALL USING (auth.role() = 'service_role');
